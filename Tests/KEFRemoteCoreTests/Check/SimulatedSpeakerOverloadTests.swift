import Foundation
import Testing
@testable import KEFRemoteCore

/// The simulated speaker falls over the way the real gen-1 LSX did on
/// 6 Oct 2026: crossed replies when exchanges overlap, then a control
/// server that refuses everything until it is power cycled at the wall.
/// So a change that lets a burst through again fails here, not on the
/// speaker.
struct SimulatedSpeakerOverloadTests {
    static let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    static let forty = VolumeState(level: 40, isMuted: false)
    static let step = 2

    // MARK: - The model

    /// A request on top of one whose reply hasn't been read crosses the
    /// replies on the one stream (the app read `52 12 FF` where it
    /// expected 5 bytes), and the control server goes down.
    @Test func aRequestOnTopOfAnotherCrossesTheRepliesAndCrashesIt() throws {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)

        try speaker.request(KEFCommand.getVolume())
        try speaker.request(KEFCommand.setVolume(50))

        #expect(speaker.hasCrashed)
        #expect(speaker.crashReason == "2 exchanges at once on its one connection")
        // The write's reader takes the start of the volume reply...
        #expect(try speaker.readReply(KEFCommand.setResponseSize) == Data([0x52, 0x25, 0x81]))
        // ...and the read gets the rest of it, then the ack.
        #expect(try speaker.readReply(KEFCommand.getResponseSize) == Data([40, 0x00, 0x52, 0x11, 0xFF]))
    }

    /// Once down, every exchange and connection is refused; its own
    /// standby doesn't help, only the wall switch.
    @Test func onceCrashedItRefusesEverythingUntilPowerCycledAtTheWall() async throws {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)
        try speaker.request(KEFCommand.getVolume())
        try speaker.request(KEFCommand.setVolume(50))

        await #expect(throws: KEFError.connectionRefused) {
            _ = try await speaker.send(KEFCommand.getVolume(), expectResponseBytes: KEFCommand.getResponseSize)
        }
        #expect(throws: KEFError.connectionRefused) { try speaker.openConnection() }

        speaker.powerCycleAtWall()

        #expect(!speaker.hasCrashed)
        try speaker.openConnection()
        let controller = SpeakerController(connection: speaker)
        // The write that overlapped was taken before it went down.
        #expect(try await controller.getVolumeState() == VolumeState(level: 50, isMuted: false))
    }

    /// ~176 power writes in ~100 ms stopped it answering.
    @Test func moreWritesThanItTakesInABurstCrashIt() async throws {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on, replyTime: .zero)
        let write = KEFCommand.setVolume(VolumeCoding.encode(level: 40, isMuted: false))

        for _ in 0..<SimulatedSpeaker.maxWritesInBurst {
            _ = try await speaker.send(write, expectResponseBytes: KEFCommand.setResponseSize)
        }
        #expect(!speaker.hasCrashed)

        _ = try await speaker.send(write, expectResponseBytes: KEFCommand.setResponseSize)
        #expect(speaker.crashReason == "21 writes within 100 ms")
        await #expect(throws: KEFError.connectionRefused) {
            _ = try await speaker.send(write, expectResponseBytes: KEFCommand.setResponseSize)
        }
    }

    /// One write after another, each waiting for its ack, is no burst.
    @Test func writesOneAfterAnotherAtItsPaceAreFine() async throws {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)
        let controller = SpeakerController(connection: speaker)

        for level in 0..<100 { try await controller.setVolume(level) }

        #expect(!speaker.hasCrashed)
        #expect(speaker.volume == VolumeState(level: 99, isMuted: false))
    }

    /// Several connection attempts at once (two reconnects together,
    /// 18:36:38-41) and it refused every connection after.
    @Test func moreConnectionOpensAtOnceThanItTakesCrashIt() throws {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)

        for _ in 0..<SimulatedSpeaker.maxConnectionOpensInWindow { try speaker.openConnection() }
        #expect(!speaker.hasCrashed)

        #expect(throws: KEFError.connectionRefused) { try speaker.openConnection() }
        #expect(speaker.crashReason == "4 connection opens within 2 s")
    }

    /// One open per reconnector wait never adds up to a burst.
    @Test func opensSpreadOutAreFine() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on, clock: clock)

        for _ in 0..<10 {
            try speaker.openConnection()
            await clock.sleep(for: SpeakerReconnector.firstWait)
        }

        #expect(!speaker.hasCrashed)
    }

    // MARK: - Control: without the queue it falls over

    /// Exchanges fired at it together, as the app's presses were before
    /// one command talked to the speaker at a time: it goes down.
    @Test func rawExchangesTogetherWithoutTheQueueCrashIt() async {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)
        let write = KEFCommand.setVolume(VolumeCoding.encode(level: 45, isMuted: false))

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    if index.isMultiple(of: 2) {
                        _ = try? await speaker.send(KEFCommand.getVolume(), expectResponseBytes: KEFCommand.getResponseSize)
                    } else {
                        _ = try? await speaker.send(write, expectResponseBytes: KEFCommand.setResponseSize)
                    }
                }
            }
        }

        #expect(speaker.mostExchangesAtOnce > 1)
        #expect(speaker.hasCrashed)
        await #expect(throws: KEFError.connectionRefused) {
            _ = try await speaker.send(KEFCommand.getVolume(), expectResponseBytes: KEFCommand.getResponseSize)
        }
    }

    /// Two controllers on the one speaker, as when two reconnects each
    /// made one: each has its own queue, so their presses overlap.
    @Test func twoControllersAtOnceCrashIt() async {
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on)
        let first = SpeakerController(connection: speaker)
        let second = SpeakerController(connection: speaker)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { _ = try? await first.raiseVolume(by: Self.step) }
                group.addTask { _ = try? await second.raiseVolume(by: Self.step) }
            }
        }

        #expect(speaker.hasCrashed)
    }

    // MARK: - Through the app's own path it stands

    /// A burst like the hand test's, through the app's path: the
    /// controller's one-at-a-time queue, quick presses adding up
    /// (``VolumePresses``), the power toggle guard and the reconnector.
    /// The speaker stays up, every press lands, and the power changed as
    /// many times as toggles got through.
    @Test func aBurstThroughTheAppsPathLeavesItStandingAtTheRightLevel() async {
        let clock = SimulatedClock()
        let thirty = VolumeState(level: 30, isMuted: false)
        let speaker = SimulatedSpeaker(volume: thirty, source: Self.on, clock: clock)
        let app = SimulatedApp(speaker: speaker, clock: clock)
        app.connect()
        let ups = 20, mutes = 2, toggles = 50

        let results = await withTaskGroup(of: PowerToggleResult?.self) { group in
            for index in 0..<toggles {
                group.addTask { await app.togglePower() }
                if index < ups { group.addTask { await app.press(.up, step: Self.step); return nil } }
                if index < mutes { group.addTask { await app.press(.mute, step: Self.step); return nil } }
            }
            var results: [PowerToggleResult] = []
            for await result in group { if let result { results.append(result) } }
            return results
        }

        #expect(!speaker.hasCrashed, "crashed: \(speaker.crashReason ?? "")")
        #expect(speaker.mostExchangesAtOnce == 1)
        #expect(app.skipped == 0)
        #expect(app.reconnectsWaiting == 0)
        #expect(speaker.volume == VolumeState(level: 30 + ups * Self.step, isMuted: false))
        // Every toggle answered: most ignored as a repeat, at least one sent.
        #expect(results.count == toggles)
        let sent = results.filter { $0 == .turnedOn || $0 == .turnedOff }.count
        #expect(sent >= 1)
        #expect(speaker.source.isPoweredOn == sent.isMultiple(of: 2))
    }

    /// After it went down, the reconnector asks once per wait (2, 4, 8 s),
    /// never a burst of opens; once power cycled, the next reconnect
    /// connects and presses work again.
    @Test func aCrashedSpeakerIsAskedOncePerWaitAndComesBackAfterAPowerCycle() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: Self.forty, source: Self.on, clock: clock)
        let app = SimulatedApp(speaker: speaker, clock: clock)
        app.connect()
        try speaker.request(KEFCommand.getVolume())
        try speaker.request(KEFCommand.getSource())

        #expect(await app.press(.up, step: Self.step) == nil)
        #expect(!app.isConnected)
        #expect(await app.press(.up, step: Self.step) == nil)
        #expect(app.skipped == 1)

        for _ in 0..<3 {
            await app.runNextReconnect()
            #expect(!app.isConnected)
            #expect(app.reconnectsWaiting == 1)
        }
        #expect(app.log.messages(at: .info).contains {
            $0.hasPrefix("Command failed (connectionRefused): dropping the connection; reconnecting in 10 s")
        })

        speaker.powerCycleAtWall()
        await app.runNextReconnect()

        #expect(app.isConnected)
        #expect(await app.press(.up, step: Self.step) != nil)
        #expect(speaker.volume == VolumeState(level: 42, isMuted: false))
        #expect(!speaker.hasCrashed)
    }
}
