import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerControllerStatusTests {
    let mock: MockSpeakerConnection
    let controller: SpeakerController

    init() {
        mock = MockSpeakerConnection()
        controller = SpeakerController(connection: mock)
    }

    // MARK: - Input

    @Test func testGetInputReturnsCurrentSource() async throws {
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00])]
        let input = try await controller.getInput()
        #expect(input == .optical)
    }

    @Test func testSetInputPreservesOtherBits() async throws {
        let current = SourceByte(isPoweredOn: true, isInversed: true, standby: .never, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, current.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.setInput(.wifi)
        let expected = current.with(input: .wifi)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    // MARK: - Standby

    @Test func testGetStandbyReturnsCurrentMode() async throws {
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00])]
        let standby = try await controller.getStandby()
        #expect(standby == .never)
    }

    @Test func testSetStandbyPreservesOtherBits() async throws {
        let current = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, current.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.setStandby(.never)
        let expected = current.with(standby: .never)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    // MARK: - Status

    @Test func testGetStatusReturnsAllFields() async throws {
        let source = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x25, 0x81, 70, 0x00]),               // GET volume
            Data([0x52, 0x30, 0x81, source.encode(), 0x00]),   // GET source
        ]
        let status = try await controller.getStatus()
        #expect(status.volume.level == 70)
        #expect(!status.volume.isMuted)
        #expect(status.isPoweredOn)
        #expect(status.input == .optical)
        #expect(status.standby == .sixtyMinutes)
    }
}
