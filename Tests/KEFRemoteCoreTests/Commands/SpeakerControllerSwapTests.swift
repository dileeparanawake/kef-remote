import Testing
import Foundation
@testable import KEFRemoteCore

/// `setLeftRightSwapped(_:)`: bit 6 of the source byte, read-modify-write,
/// from the Swap left and right switch in Settings.
struct SpeakerControllerSwapTests {
    let mock = MockSpeakerConnection()
    let log = MockKEFLog()

    private static let ack = Data([0x52, 0x11, 0xFF])

    private static func reply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    private let onOptical = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)

    /// A controller whose reported source bytes are recorded, in order.
    private func recordingController() -> (SpeakerController, () -> [SourceByte]) {
        var sources: [SourceByte] = []
        let controller = SpeakerController(connection: mock, log: log.handler, onSourceByte: { sources.append($0) })
        return (controller, { sources })
    }

    @Test func swappingWritesBitSixAndKeepsTheRest() async throws {
        mock.responses = [Self.reply(onOptical), Self.ack]
        let (controller, _) = recordingController()

        try await controller.setLeftRightSwapped(true)

        #expect(mock.sentCommands == [
            KEFCommand.getSource(),
            KEFCommand.setSource(onOptical.with(isInversed: true).encode()),
        ])
    }

    @Test func unswappingClearsBitSix() async throws {
        let swapped = onOptical.with(isInversed: true)
        mock.responses = [Self.reply(swapped), Self.ack]
        let (controller, _) = recordingController()

        try await controller.setLeftRightSwapped(false)

        #expect(mock.sentCommands[1] == KEFCommand.setSource(onOptical.encode()))
    }

    @Test func theByteWrittenIsReported() async throws {
        mock.responses = [Self.reply(onOptical), Self.ack]
        let (controller, sources) = recordingController()

        try await controller.setLeftRightSwapped(true)

        #expect(sources().last == onOptical.with(isInversed: true))
    }

    @Test func swappingLogsOneLine() async throws {
        mock.responses = [Self.reply(onOptical), Self.ack]
        let (controller, _) = recordingController()

        try await controller.setLeftRightSwapped(true)

        #expect(log.messages(at: .info).filter { $0.hasPrefix("swap left and right") }
            == ["swap left and right: off -> on"])
    }

    @Test func aSpeakerAlreadyThatWayIsOnlyRead() async throws {
        mock.responses = [Self.reply(onOptical.with(isInversed: true))]
        let (controller, _) = recordingController()

        try await controller.setLeftRightSwapped(true)

        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("swap left and right: already on"))
    }

    /// After the Mac slept the app asks for 20-minute standby, and the
    /// speaker then goes off by itself. Writing the swap then would send
    /// power off with 20 minutes, which crashes it. Off, it ignores the
    /// swap anyway, so nothing is sent.
    @Test func aSpeakerThatIsOffIsOnlyRead() async throws {
        let offTwenty = SourceByte(isPoweredOn: false, isInversed: false, standby: .twentyMinutes, input: .optical)
        mock.responses = [Self.reply(offTwenty)]
        let (controller, _) = recordingController()

        try await controller.setLeftRightSwapped(true)

        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("swap left and right: not sent, the speaker is off and ignores it while off"))
    }

    @Test func aFailedReadWritesNothingAndThrows() async {
        mock.errorToThrow = .commandTimeout
        let (controller, _) = recordingController()

        await #expect(throws: KEFError.commandTimeout) { try await controller.setLeftRightSwapped(true) }

        #expect(mock.sentCommands == [KEFCommand.getSource()])
    }
}
