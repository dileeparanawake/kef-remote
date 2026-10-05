import Testing
import Foundation
@testable import KEFRemoteCore

/// The controller reports whether the speaker answered each exchange.
/// This is the live state behind the menu bar's "Connected" line.
struct SpeakerControllerReplyTests {

    /// A controller whose replies are recorded, in order.
    private func recordingController(mock: MockSpeakerConnection) -> (SpeakerController, () -> [SpeakerReply]) {
        var replies: [SpeakerReply] = []
        let controller = SpeakerController(connection: mock, onReply: { replies.append($0) })
        return (controller, { replies })
    }

    @Test func whenTheSpeakerAnswersTheReplyIsAnswered() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70, 0x00])]
        let (controller, replies) = recordingController(mock: mock)

        _ = try await controller.getVolumeState()

        #expect(replies() == [.answered])
    }

    @Test func whenTheSpeakerCannotBeReachedTheReplyIsUnreachable() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let (controller, replies) = recordingController(mock: mock)

        _ = try? await controller.getVolumeState()

        #expect(replies() == [.unreachable("connectionFailed(\"timed out\")")])
    }

    @Test func aBadlyShapedAnswerStillCountsAsAnswered() async {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0xFF, 0x00, 0x00, 0x00, 0x00])]
        let (controller, replies) = recordingController(mock: mock)

        _ = try? await controller.getVolumeState()

        #expect(replies() == [.answered])
    }

    @Test func anEmptyReadReportsNothingBecauseTheLinkIsUnknown() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .invalidResponse
        let (controller, replies) = recordingController(mock: mock)

        _ = try? await controller.getVolumeState()

        #expect(replies().isEmpty)
    }

    @Test func checkingTheConnectionReadsTheSourceByteOnce() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x30, 0x81, 0x82, 0x00])]
        let (controller, replies) = recordingController(mock: mock)

        try await controller.checkConnection()

        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(replies() == [.answered])
    }
}
