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
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),  // GET source
            Data([0x52, 0x11, 0xFF]),                                // SET response
        ]
        try await controller.powerOn()
        let expectedSet = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expectedSet.encode()))
    }

    @Test func testPowerOnPreservesExistingInputAndStandby() async throws {
        let currentSource = SourceByte(isPoweredOn: false, isInversed: true, standby: .never, input: .usb)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.powerOn()
        let expected = currentSource.with(isPoweredOn: true)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    @Test func powerOnSwitchesToTheChosenInputInTheSameWrite() async throws {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .wifi)
        mock.responses = [
            Data([0x52, 0x30, 0x81, off.encode(), 0x00]),  // GET source
            Data([0x52, 0x11, 0xFF]),                      // SET power on + input
        ]
        try await controller.powerOn(applying: SpeakerSettings(powerOnInput: .optical))
        #expect(mock.sentCommands.count == 2)  // one read, one write
        let expected = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    @Test func powerOnLogsWhatItSent() async throws {
        let log = MockKEFLog()
        let controller = SpeakerController(connection: mock, log: log.handler)
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .wifi)
        mock.responses = [
            Data([0x52, 0x30, 0x81, off.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.powerOn(applying: SpeakerSettings(powerOnInput: .optical))
        #expect(log.messages(at: .info).contains(
            "powerOn: sending power=on input=optical standby=never "
            + "(was input=wifi standby=never; power-on input: Optical, standby: Don't change)"
        ))
    }

    // MARK: - powerOff

    @Test func testPowerOffSetsPowerBitToOne() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.powerOff()
        let expected = currentSource.with(isPoweredOn: false)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    // MARK: - Standby crash workaround

    @Test func testPowerOffSwitchesFrom20MinTo60MinBeforePowerOff() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),  // GET source
            Data([0x52, 0x11, 0xFF]),  // SET standby to 60min response
            Data([0x52, 0x11, 0xFF]),  // SET power off response
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
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.powerOff()
        #expect(mock.sentCommands.count == 2)  // Only GET + SET (no standby fix)
    }

    @Test func testPowerOffDoesNotTouchStandbyWhenNever() async throws {
        let currentSource = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, currentSource.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.powerOff()
        #expect(mock.sentCommands.count == 2)
    }

    // MARK: - togglePower

    @Test func togglePowerTurnsAnOffSpeakerOn() async throws {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, off.encode(), 0x00]),  // GET source
            Data([0x52, 0x11, 0xFF]),                      // SET power on
        ]
        let isOn = try await controller.togglePower()
        #expect(isOn)
        #expect(mock.sentCommands.count == 2)  // one read, one write
        #expect(mock.sentCommands[1] == KEFCommand.setSource(off.with(isPoweredOn: true).encode()))
    }

    @Test func togglePowerOnSwitchesToTheChosenInput() async throws {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .bluetoothPaired)
        mock.responses = [
            Data([0x52, 0x30, 0x81, off.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        let isOn = try await controller.togglePower(applying: SpeakerSettings(powerOnInput: .aux))
        #expect(isOn)
        #expect(mock.sentCommands.count == 2)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(off.with(isPoweredOn: true).with(input: .aux).encode()))
    }

    /// The input choice is for turning on; turning off leaves the input alone.
    @Test func togglePowerOffIgnoresTheInputChoice() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        mock.responses = [
            Data([0x52, 0x30, 0x81, on.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        try await controller.togglePower(applying: SpeakerSettings(powerOnInput: .optical))
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(isPoweredOn: false).encode()))
    }

    @Test func togglePowerTurnsAnOnSpeakerOff() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .usb)
        mock.responses = [
            Data([0x52, 0x30, 0x81, on.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),
        ]
        let isOn = try await controller.togglePower()
        #expect(!isOn)
        #expect(mock.sentCommands.count == 2)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(isPoweredOn: false).encode()))
    }

    @Test func togglePowerOffKeepsTheTwentyMinuteStandbyWorkaround() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .optical)
        mock.responses = [
            Data([0x52, 0x30, 0x81, on.encode(), 0x00]),
            Data([0x52, 0x11, 0xFF]),  // SET standby to 60min
            Data([0x52, 0x11, 0xFF]),  // SET power off
        ]
        let isOn = try await controller.togglePower()
        #expect(!isOn)
        let standbyFix = on.with(standby: .sixtyMinutes)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(standbyFix.encode()))
        #expect(mock.sentCommands[2] == KEFCommand.setSource(standbyFix.with(isPoweredOn: false).encode()))
    }
}
