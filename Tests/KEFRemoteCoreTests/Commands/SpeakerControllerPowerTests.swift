import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerControllerPowerTests {
    let mock: MockSpeakerConnection
    let controller: SpeakerController

    init() {
        mock = MockSpeakerConnection()
        controller = SpeakerController(connection: mock)
    }

    // MARK: - powerOn

    @Test func testPowerOnSetsPowerBitToZero() async throws {
        let currentSource = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),  // GET source
            Data([0x52, 0x30, 0x81, 0x1B]),                    // SET response
        ]
        try await controller.powerOn()
        let expectedSet = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expectedSet.encode()))
    }

    @Test func testPowerOnPreservesExistingInputAndStandby() async throws {
        let currentSource = SourceByte(isPoweredOn: false, isInversed: true, standby: .never, input: .usb)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),
            Data([0x52, 0x30, 0x81, 0x00]),
        ]
        try await controller.powerOn()
        let expected = currentSource.with(isPoweredOn: true)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    // MARK: - powerOff

    @Test func testPowerOffSetsPowerBitToOne() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),
            Data([0x52, 0x30, 0x81, 0x00]),
        ]
        try await controller.powerOff()
        let expected = currentSource.with(isPoweredOn: false)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    // MARK: - Standby crash workaround

    @Test func testPowerOffSwitchesFrom20MinTo60MinBeforePowerOff() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),  // GET source
            Data([0x52, 0x30, 0x81, 0x00]),  // SET standby to 60min response
            Data([0x52, 0x30, 0x81, 0x00]),  // SET power off response
        ]
        try await controller.powerOff()
        // Should send 3 commands: GET, SET (standby fix), SET (power off)
        #expect(mock.sentCommands.count == 3)
        // Second command: change standby from 20min to 60min, keep power ON
        let standbyFix = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(standbyFix.encode()))
        // Third command: now power off (with 60min standby)
        let powerOff = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .optical)
        #expect(mock.sentCommands[2] == KEFCommand.setSource(powerOff.encode()))
    }

    @Test func testPowerOffDoesNotTouchStandbyWhen60Min() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),
            Data([0x52, 0x30, 0x81, 0x00]),
        ]
        try await controller.powerOff()
        #expect(mock.sentCommands.count == 2)  // Only GET + SET (no standby fix)
    }

    @Test func testPowerOffDoesNotTouchStandbyWhenNever() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode()]),
            Data([0x52, 0x30, 0x81, 0x00]),
        ]
        try await controller.powerOff()
        #expect(mock.sentCommands.count == 2)
    }
}
