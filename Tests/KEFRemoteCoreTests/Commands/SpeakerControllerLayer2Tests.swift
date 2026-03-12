import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerControllerLayer2Tests {

    // MARK: - Helpers

    private func makeController(
        mock: MockSpeakerConnection,
        log: @escaping KEFLogHandler = { _, _ in }
    ) -> SpeakerController {
        SpeakerController(connection: mock, log: log)
    }

    private func captureController(mock: MockSpeakerConnection) -> (SpeakerController, () -> [(KEFLogLevel, String)]) {
        var logged: [(KEFLogLevel, String)] = []
        let controller = makeController(mock: mock) { level, message in
            logged.append((level, message))
        }
        return (controller, { logged })
    }

    // MARK: - sendAndReceive: logging

    @Test func testSendAndReceiveLogsHexSendBytes() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70, 0x00])]
        let (controller, logs) = captureController(mock: mock)
        _ = try await controller.getVolumeState()
        let debugMessages = logs().filter { $0.0 == .debug }.map { $0.1 }
        #expect(debugMessages.contains { $0.contains("47 25 80") })
    }

    @Test func testSendAndReceiveLogsHexReceiveBytes() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70, 0x00])]
        let (controller, logs) = captureController(mock: mock)
        _ = try await controller.getVolumeState()
        let debugMessages = logs().filter { $0.0 == .debug }.map { $0.1 }
        #expect(debugMessages.contains { $0.contains("52 25 81") })
    }

    @Test func testSendAndReceiveLogsErrorWithHexDumpOnInvalidResponse() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0xFF, 0x00, 0x00, 0x00, 0x00])]
        let (controller, logs) = captureController(mock: mock)
        _ = try? await controller.getVolumeState()
        let errorMessages = logs().filter { $0.0 == .error }.map { $0.1 }
        #expect(!errorMessages.isEmpty)
        #expect(errorMessages.contains { $0.contains("FF 00 00") })
    }

    // MARK: - sendAndReceive: GET response validation

    @Test func testSendAndReceiveAcceptsValidGetResponse() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70, 0x00])]
        let controller = makeController(mock: mock)
        let state = try await controller.getVolumeState()
        #expect(state.level == 70)
    }

    @Test func testSendAndReceiveRejectsGetResponseWithWrongByteCount() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70])]  // 4 bytes, not 5
        let controller = makeController(mock: mock)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await controller.getVolumeState()
        }
    }

    @Test func testSendAndReceiveRejectsGetResponseWithWrongFirstByte() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0xFF, 0x25, 0x81, 70, 0x00])]
        let controller = makeController(mock: mock)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await controller.getVolumeState()
        }
    }

    @Test func testSendAndReceiveRejectsGetResponseWithWrongRegister() async throws {
        // Response echoes register 0x30 but we asked for volume (0x25)
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x30, 0x81, 70, 0x00])]
        let controller = makeController(mock: mock)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await controller.getVolumeState()
        }
    }

    @Test func testSendAndReceiveRejectsGetResponseWithWrongThirdByte() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x00, 70, 0x00])]  // byte[2] should be 0x81
        let controller = makeController(mock: mock)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await controller.getVolumeState()
        }
    }

    // MARK: - sendAndReceive: SET response validation

    @Test func testSendAndReceiveAcceptsValidSetAck() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x11, 0xFF])]
        let controller = makeController(mock: mock)
        try await controller.setVolume(50)  // should not throw
    }

    @Test func testSendAndReceiveRejectsInvalidSetAck() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x11, 0x00])]  // wrong last byte
        let controller = makeController(mock: mock)
        await #expect(throws: KEFError.invalidResponse) {
            try await controller.setVolume(50)
        }
    }

    // MARK: - getVolumeState

    @Test func testGetVolumeStateReturnsDecodedVolume() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 70, 0x00])]
        let controller = makeController(mock: mock)
        let state = try await controller.getVolumeState()
        #expect(state.level == 70)
        #expect(!state.isMuted)
    }

    @Test func testGetVolumeStateDecodesMutedVolume() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 198, 0x00])]  // 128 + 70
        let controller = makeController(mock: mock)
        let state = try await controller.getVolumeState()
        #expect(state.level == 70)
        #expect(state.isMuted)
    }

    @Test func testGetVolumeStateSendsGetVolumeCommand() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 55, 0x00])]
        let controller = makeController(mock: mock)
        _ = try await controller.getVolumeState()
        #expect(mock.sentCommands == [KEFCommand.getVolume()])
    }

    // MARK: - getPowerState

    @Test func testGetPowerStateReturnsDecodedSourceByte() async throws {
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00])]
        let controller = makeController(mock: mock)
        let result = try await controller.getPowerState()
        #expect(result.isPoweredOn == true)
        #expect(result.input == .optical)
        #expect(result.standby == .never)
    }

    @Test func testGetPowerStateSendsGetSourceCommand() async throws {
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00])]
        let controller = makeController(mock: mock)
        _ = try await controller.getPowerState()
        #expect(mock.sentCommands == [KEFCommand.getSource()])
    }

    // MARK: - getState

    @Test func testGetStateSendsGetVolumeBeforeGetSource() async throws {
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),
            Data([0x52, 0x30, 0x81, source.encode(), 0x00]),
        ]
        let controller = makeController(mock: mock)
        _ = try await controller.getState()
        #expect(mock.sentCommands.count == 2)
        #expect(mock.sentCommands[0] == KEFCommand.getVolume())
        #expect(mock.sentCommands[1] == KEFCommand.getSource())
    }

    @Test func testGetStateReturnsCombinedVolumeAndSource() async throws {
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),
            Data([0x52, 0x30, 0x81, source.encode(), 0x00]),
        ]
        let controller = makeController(mock: mock)
        let state = try await controller.getState()
        #expect(state.volume.level == 70)
        #expect(!state.volume.isMuted)
        #expect(state.isPoweredOn == true)
        #expect(state.input == .optical)
        #expect(state.standby == .sixtyMinutes)
    }

    @Test func testGetStateIsSequential() async throws {
        // Verifies that the volume response is fully consumed before the source GET is sent.
        // MockSpeakerConnection processes responses in FIFO order — if the calls overlapped,
        // the source GET would consume the volume response and fail.
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: false, isInversed: false, standby: .twentyMinutes, input: .bluetoothPaired)
        mock.responses = [
            Data([0x52, 0x25, 0x81, 30, 0x00]),
            Data([0x52, 0x30, 0x81, source.encode(), 0x00]),
        ]
        let controller = makeController(mock: mock)
        let state = try await controller.getState()
        #expect(state.volume.level == 30)
        #expect(state.isPoweredOn == false)
        #expect(state.input == .bluetoothPaired)
    }

    // MARK: - getVolumeState and getPowerState are independently usable

    @Test func testGetVolumeStateWorksWithoutGetPowerState() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x25, 0x81, 55, 0x00])]
        let controller = makeController(mock: mock)
        let state = try await controller.getVolumeState()
        #expect(state.level == 55)
        #expect(mock.sentCommands.count == 1)
    }

    @Test func testGetPowerStateWorksWithoutGetVolumeState() async throws {
        let mock = MockSpeakerConnection()
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00])]
        let controller = makeController(mock: mock)
        let result = try await controller.getPowerState()
        #expect(result.input == .wifi)
        #expect(mock.sentCommands.count == 1)
    }
}
