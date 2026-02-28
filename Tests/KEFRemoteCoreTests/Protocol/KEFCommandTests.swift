import Foundation
import Testing
@testable import KEFRemoteCore

// MARK: - GET commands are 3 bytes: [0x47, register, 0x80]

@Test func testGetVolumeCommand() {
    let command = KEFCommand.getVolume()
    #expect(command == Data([0x47, 0x25, 0x80]))
}

@Test func testGetSourceCommand() {
    let command = KEFCommand.getSource()
    #expect(command == Data([0x47, 0x30, 0x80]))
}

// MARK: - SET commands are 4 bytes: [0x53, register, 0x81, value]

@Test func testSetVolumeCommand() {
    let command = KEFCommand.setVolume(70)
    #expect(command == Data([0x53, 0x25, 0x81, 70]))
}

@Test func testSetSourceCommand() {
    let command = KEFCommand.setSource(0x1B)
    #expect(command == Data([0x53, 0x30, 0x81, 0x1B]))
}

// MARK: - Response parsing extracts byte 4 (index 3)

@Test func testParseResponseReturnsPayloadByte() {
    let response = Data([0x52, 0x25, 0x81, 0x46])
    #expect(KEFCommand.parseResponse(response) == 0x46)
}

@Test func testParseResponseReturnsNilForShortData() {
    let response = Data([0x52, 0x25])
    #expect(KEFCommand.parseResponse(response) == nil)
}

@Test func testParseResponseReturnsNilForEmptyData() {
    #expect(KEFCommand.parseResponse(Data()) == nil)
}
