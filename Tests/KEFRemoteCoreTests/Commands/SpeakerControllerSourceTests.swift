import Testing
import Foundation
@testable import KEFRemoteCore

/// The controller reports the speaker's source byte each time it learns
/// it, so the menu can tick the input without reading it again.
struct SpeakerControllerSourceTests {
    let mock = MockSpeakerConnection()
    let log = MockKEFLog()

    private static let ack = Data([0x52, 0x11, 0xFF])

    private static func reply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    private let onOptical = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)

    /// A controller whose reported source bytes are recorded, in order.
    private func recordingController() -> (SpeakerController, () -> [SourceByte]) {
        var sources: [SourceByte] = []
        let controller = SpeakerController(connection: mock, log: log.handler, onSourceByte: { sources.append($0) })
        return (controller, { sources })
    }

    @Test func aReadReportsTheSourceByte() async throws {
        mock.responses = [Self.reply(onOptical)]
        let (controller, sources) = recordingController()

        _ = try await controller.getSourceByte()

        #expect(sources() == [onOptical])
    }

    @Test func theConnectionCheckReportsTheSourceByte() async {
        mock.responses = [Self.reply(onOptical)]
        let (controller, sources) = recordingController()

        #expect(await controller.checkConnection(.savedIP) == .answered)

        #expect(sources() == [onOptical])
    }

    @Test func switchingInputReportsTheByteItWrote() async throws {
        mock.responses = [Self.reply(onOptical), Self.ack]
        let (controller, sources) = recordingController()

        try await controller.setInput(.wifi)

        #expect(mock.sentCommands[1] == KEFCommand.setSource(onOptical.with(input: .wifi).encode()))
        #expect(sources() == [onOptical, onOptical.with(input: .wifi)])
    }

    /// Without an ack the speaker may not have changed, so the last byte stands.
    @Test func aWriteWithNoAckReportsNothingNew() async {
        mock.responses = [Self.reply(onOptical), Data([0x00, 0x00, 0x00])]
        let (controller, sources) = recordingController()

        await #expect(throws: KEFError.self) { try await controller.setInput(.wifi) }

        #expect(sources() == [onOptical])
    }

    @Test func aFailedReadReportsNothing() async {
        mock.errorToThrow = .connectionFailed("timed out")
        let (controller, sources) = recordingController()

        _ = try? await controller.getSourceByte()

        #expect(sources().isEmpty)
    }

    @Test func aVolumeReadReportsNoSourceByte() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 40, 0x00])]
        let (controller, sources) = recordingController()

        _ = try await controller.getVolumeState()

        #expect(sources().isEmpty)
    }

    @Test func switchingInputLogsOneLine() async throws {
        mock.responses = [Self.reply(onOptical), Self.ack]
        let (controller, _) = recordingController()

        try await controller.setInput(.usb)

        #expect(log.messages(at: .info).filter { $0.hasPrefix("setInput") } == ["setInput: Optical -> USB"])
    }
}
