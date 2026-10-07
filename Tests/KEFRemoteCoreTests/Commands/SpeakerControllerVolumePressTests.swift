import Foundation
import Testing
@testable import KEFRemoteCore

/// Volume and mute presses from the keys: those that come while one is
/// waiting its turn add up into its one write (``VolumePresses``).
struct SpeakerControllerVolumePressTests {
    static let step = 5
    static let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
    static let ack = Data([0x52, 0x11, 0xFF])

    static func volumeReply(_ level: UInt8) -> Data { Data([0x52, 0x25, 0x81, level, 0x00]) }
    static func sourceReply() -> Data { Data([0x52, 0x30, 0x81, on.encode(), 0x00]) }

    /// Holds the speaker with a source read, so presses queue behind it.
    private func busyController(_ responses: [Data], log: MockKEFLog = MockKEFLog())
        -> (GatedSpeakerConnection, SpeakerController, Task<SourceByte, Error>) {
        let connection = GatedSpeakerConnection(responses: [Self.sourceReply()] + responses)
        let controller = SpeakerController(connection: connection, log: log.handler)
        let blocker = Task { try await controller.getSourceByte() }
        return (connection, controller, blocker)
    }

    private func waitForFirstSend(_ connection: GatedSpeakerConnection) async {
        while connection.sentCommands.isEmpty { await Task.yield() }
    }

    @Test func threeUpsWhileBusyAreOneWriteOfFifteen() async throws {
        let log = MockKEFLog()
        let (connection, controller, blocker) = busyController([Self.volumeReply(45), Self.ack], log: log)
        await waitForFirstSend(connection)

        let first = Task { try await controller.press(.up, step: Self.step) }
        while !controller.hasVolumeTurnQueued { await Task.yield() }
        let second = try await controller.press(.up, step: Self.step)
        let third = try await controller.press(.up, step: Self.step)
        #expect(second == .addedToWaiting)
        #expect(third == .addedToWaiting)

        connection.open()
        _ = try await blocker.value
        let result = try await first.value

        #expect(connection.sentCommands == [
            KEFCommand.getSource(),
            KEFCommand.getVolume(),
            KEFCommand.setVolume(VolumeCoding.encode(level: 60, isMuted: false)),
        ])
        guard case .sent(let presses, let now) = result else {
            Issue.record("the first press should send, got \(result)")
            return
        }
        #expect(presses.count == 3)
        #expect(now == VolumeState(level: 60, isMuted: false))
        #expect(log.messages(at: .info).contains("3 presses combined (volume up ×3): 45% → 60%"))
    }

    @Test func twoMutePressesWhileBusySendNoWrite() async throws {
        let (connection, controller, blocker) = busyController([Self.volumeReply(45)])
        await waitForFirstSend(connection)

        let first = Task { try await controller.press(.mute, step: Self.step) }
        while !controller.hasVolumeTurnQueued { await Task.yield() }
        #expect(try await controller.press(.mute, step: Self.step) == .addedToWaiting)

        connection.open()
        _ = try await blocker.value
        let result = try await first.value

        #expect(connection.sentCommands == [KEFCommand.getSource(), KEFCommand.getVolume()])
        guard case .sent(_, let now) = result else {
            Issue.record("the first press should read, got \(result)")
            return
        }
        #expect(now == VolumeState(level: 45, isMuted: false))
    }

    /// A press after the last one's write starts a new change.
    @Test func pressesOneAfterAnotherEachWrite() async throws {
        let speaker = OverlapProbeSpeaker(volume: VolumeState(level: 40, isMuted: false))
        let controller = SpeakerController(connection: speaker)

        _ = try await controller.press(.up, step: Self.step)
        let result = try await controller.press(.up, step: Self.step)

        #expect(result == .sent(Self.presses(.up), now: VolumeState(level: 50, isMuted: false)))
        #expect(speaker.volume == VolumeState(level: 50, isMuted: false))
    }

    /// The hand test's burst: presses together, never two exchanges at
    /// once, and every press counted.
    @Test func aBurstTogetherLandsEveryPress() async throws {
        let speaker = OverlapProbeSpeaker(volume: VolumeState(level: 40, isMuted: false))
        let controller = SpeakerController(connection: speaker)
        let presses = 8

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<presses {
                group.addTask { _ = try await controller.press(.up, step: Self.step) }
            }
            try await group.waitForAll()
        }

        #expect(speaker.mostAtOnce == 1)
        #expect(speaker.volume == VolumeState(level: 80, isMuted: false))
        let writes = speaker.sentCommands.filter { !$0.isRead }.count
        #expect(writes < presses)
    }

    private static func presses(_ commands: VolumeCommand...) -> VolumePresses {
        var presses = VolumePresses()
        for command in commands { presses.add(command, step: step) }
        return presses
    }
}
