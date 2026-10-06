import Foundation
import Testing
@testable import KEFRemoteCore

/// Every command reaches the speaker one exchange at a time, however
/// many presses come together. In the hand test of 6 Oct 2026 two quick
/// volume presses each read 45% and wrote 50% (18:36:36), two more
/// crossed their replies on the one connection (18:36:38 "Invalid
/// response"), and the speaker's control server stopped taking
/// connections until it was power cycled.
struct SpeakerControllerOneAtATimeTests {
    static let step = 5

    @Test func manyRaisesTogetherEachSeeTheLastOnesWrite() async throws {
        let speaker = OverlapProbeSpeaker(volume: VolumeState(level: 40, isMuted: false))
        let controller = SpeakerController(connection: speaker)
        let presses = 5

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<presses {
                group.addTask { try await controller.raiseVolume(by: Self.step) }
            }
            try await group.waitForAll()
        }

        #expect(speaker.mostAtOnce == 1)
        #expect(speaker.volume == VolumeState(level: 40 + presses * Self.step, isMuted: false))
        // Read, write, read, write: no read slips in before the last write.
        let shape = speaker.sentCommands.map(\.isRead)
        #expect(shape == Array(repeating: [true, false], count: presses).flatMap { $0 })
    }

    @Test func twoMuteTogglesTogetherLeaveItAsItWas() async throws {
        let speaker = OverlapProbeSpeaker(volume: VolumeState(level: 45, isMuted: false))
        let controller = SpeakerController(connection: speaker)

        async let first: Void = controller.toggleMute()
        async let second: Void = controller.toggleMute()
        _ = try await (first, second)

        #expect(speaker.mostAtOnce == 1)
        #expect(speaker.volume == VolumeState(level: 45, isMuted: false))
    }

    /// A second command doesn't reach the connection until the first has
    /// its reply, and the menu sees the speaker busy meanwhile.
    @Test func aSecondCommandWaitsForTheFirstsReply() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        let connection = GatedSpeakerConnection(responses: [
            Data([0x52, 0x30, 0x81, on.encode(), 0x00]),
            Data([0x52, 0x25, 0x81, 40, 0x00]),
        ])
        let controller = SpeakerController(connection: connection)

        async let source = controller.getSourceByte()
        while connection.sentCommands.isEmpty { await Task.yield() }
        async let volume = controller.getVolumeState()
        for _ in 0..<50 { await Task.yield() }

        #expect(connection.sentCommands == [KEFCommand.getSource()])
        #expect(controller.isExchangeInFlight)
        connection.open()
        #expect(try await source == on)
        #expect(try await volume == VolumeState(level: 40, isMuted: false))
        #expect(connection.sentCommands == [KEFCommand.getSource(), KEFCommand.getVolume()])
        #expect(!controller.isExchangeInFlight)
    }

    /// Keys, the menu, Settings, wake and sleep, the menu-open read and
    /// the connection check all share the one queue.
    @Test func everyKindOfCommandWaitsItsTurn() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        let speaker = OverlapProbeSpeaker(volume: VolumeState(level: 30, isMuted: false), source: on)
        let controller = SpeakerController(connection: speaker, clock: SimulatedClock())
        let settings = SpeakerSettings(standby: .never)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = try? await controller.raiseVolume(by: Self.step) }
            group.addTask { _ = try? await controller.lowerVolume(by: Self.step) }
            group.addTask { _ = try? await controller.toggleMute() }
            group.addTask { _ = try? await controller.getSourceByte() }
            group.addTask { _ = try? await controller.switchInput(to: .wifi) }
            group.addTask { _ = try? await controller.setLeftRightSwapped(true) }
            group.addTask { _ = try? await controller.applyStandby(settings, for: .chosen) }
            group.addTask { _ = try? await controller.macWoke(settings, powerOn: false) }
            group.addTask { _ = await controller.checkConnection(.savedIP) }
        }

        #expect(speaker.mostAtOnce == 1)
    }
}
