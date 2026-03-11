import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerControllerMuteTests {
    let mock: MockSpeakerConnection
    let controller: SpeakerController

    init() {
        mock = MockSpeakerConnection()
        controller = SpeakerController(connection: mock)
    }

    // MARK: - mute

    @Test func testMuteAdds128ToCurrentVolume() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),  // GET: unmuted at 70
            Data([0x52, 0x11, 0xFF]),              // SET response
        ]
        try await controller.mute()
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(198))
    }

    @Test func testMuteDoesNothingIfAlreadyMuted() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 198, 0x00]),  // GET: already muted at 70
        ]
        try await controller.mute()
        #expect(mock.sentCommands.count == 1)  // Only GET, no SET
    }

    // MARK: - unmute

    @Test func testUnmuteSubtracts128() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 198, 0x00]),  // GET: muted at 70
            Data([0x52, 0x11, 0xFF]),               // SET response
        ]
        try await controller.unmute()
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(70))
    }

    @Test func testUnmuteDoesNothingIfNotMuted() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),  // GET: not muted
        ]
        try await controller.unmute()
        #expect(mock.sentCommands.count == 1)
    }

    // MARK: - toggleMute

    @Test func testToggleMuteMutesWhenUnmuted() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.toggleMute()
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(198))
    }

    @Test func testToggleMuteUnmutesWhenMuted() async throws {
        mock.responses = [
            Data([0x52, 0x25, 0x81, 198, 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.toggleMute()
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(70))
    }

    @Test func testToggleMuteHandlesZeroVolumeMuted() async throws {
        // Edge case: volume 0 + muted = byte 128
        mock.responses = [
            Data([0x52, 0x25, 0x81, 128, 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.toggleMute()
        #expect(mock.sentCommands[1] == KEFCommand.setVolume(0))
    }
}
