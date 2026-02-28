import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerControllerVolumeTests {
    let mock: MockSpeakerConnection
    let controller: SpeakerController

    init() {
        mock = MockSpeakerConnection()
        controller = SpeakerController(connection: mock)
    }

    // MARK: - getVolume

    @Test func testGetVolumeReturnsDecodedState() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 70])]
        let state = try await controller.getVolume()
        #expect(state.level == 70)
        #expect(!state.isMuted)
        #expect(mock.sentCommands == [KEFCommand.getVolume()])
    }

    @Test func testGetVolumeMuted() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 198])]  // 128 + 70
        let state = try await controller.getVolume()
        #expect(state.level == 70)
        #expect(state.isMuted)
    }

    // MARK: - setVolume

    @Test func testSetVolumeSendsCorrectByte() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 50])]
        try await controller.setVolume(50)
        #expect(mock.sentCommands == [KEFCommand.setVolume(50)])
    }

    @Test func testSetVolumeClampsAbove100() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 100])]
        try await controller.setVolume(150)
        #expect(mock.sentCommands == [KEFCommand.setVolume(100)])
    }

    @Test func testSetVolumeClampsBelowZero() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 0])]
        try await controller.setVolume(-10)
        #expect(mock.sentCommands == [KEFCommand.setVolume(0)])
    }

    // MARK: - raiseVolume

    @Test func testRaiseVolumeAddsToCurrentLevel() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70]),  // GET response
            Data([0x52, 0x25, 0x81, 75]),  // SET response
        ]
        try await controller.raiseVolume(by: 5)
        #expect(mock.sentCommands.count == 2)
        #expect(mock.sentCommands[0] == KEFCommand.getVolume())
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(75))
    }

    @Test func testRaiseVolumeClampsAt100() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 98]), Data([0x52, 0x25, 0x81, 100])]
        try await controller.raiseVolume(by: 5)
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(100))
    }

    @Test func testRaiseVolumePreservesMuteState() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 198]), Data([0x52, 0x25, 0x81, 203])]
        try await controller.raiseVolume(by: 5)
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(203))  // 75 + 128
    }

    // MARK: - lowerVolume

    @Test func testLowerVolumeSubtractsFromCurrentLevel() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 70]), Data([0x52, 0x25, 0x81, 65])]
        try await controller.lowerVolume(by: 5)
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(65))
    }

    @Test func testLowerVolumeClampsAtZero() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 3]), Data([0x52, 0x25, 0x81, 0])]
        try await controller.lowerVolume(by: 5)
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(0))
    }

    @Test func testLowerVolumePreservesMuteState() async throws {
        mock.responses = [Data([0x52, 0x25, 0x81, 198]), Data([0x52, 0x25, 0x81, 193])]
        try await controller.lowerVolume(by: 5)
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(193))  // 65 + 128
    }
}
