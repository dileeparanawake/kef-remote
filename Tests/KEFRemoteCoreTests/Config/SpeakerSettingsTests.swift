import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerSettingsTests {

    // MARK: - Power-on input choice

    @Test func powerOnInputIsDontChangeByDefault() {
        #expect(SpeakerSettings().powerOnInput == .dontChange)
    }

    @Test func eachChoiceNamesTheInputItWrites() {
        #expect(PowerOnInput.dontChange.input == nil)
        #expect(PowerOnInput.optical.input == .optical)
        #expect(PowerOnInput.wifi.input == .wifi)
        #expect(PowerOnInput.bluetooth.input == .bluetoothPaired)
        #expect(PowerOnInput.aux.input == .aux)
        #expect(PowerOnInput.usb.input == .usb)
    }

    @Test func theChoicesAreListedInSettingsOrder() {
        #expect(PowerOnInput.allCases.map(\.label)
            == ["Don't change", "Optical", "Wi-Fi", "Bluetooth", "Aux", "USB"])
    }

    /// Saved by name, so config.json reads "optical", not a protocol code.
    @Test func theChoiceIsSavedByName() throws {
        let data = try JSONEncoder().encode(SpeakerSettings(powerOnInput: .optical))
        #expect(String(decoding: data, as: UTF8.self) == #"{"powerOnInput":"optical"}"#)
    }

    // MARK: - The power-on byte

    @Test func dontChangeOnlySetsThePowerBit() {
        let off = SourceByte(isPoweredOn: false, isInversed: true, standby: .sixtyMinutes, input: .wifi)
        #expect(SpeakerSettings().powerOnByte(from: off) == off.with(isPoweredOn: true))
    }

    @Test func aChosenInputGoesInWithThePowerBit() {
        let off = SourceByte(isPoweredOn: false, isInversed: true, standby: .never, input: .wifi)
        let byte = SpeakerSettings(powerOnInput: .optical).powerOnByte(from: off)
        #expect(byte == SourceByte(isPoweredOn: true, isInversed: true, standby: .never, input: .optical))
    }

    /// Waking the Mac after a short sleep powers on a speaker that never
    /// went off: someone may be listening to another input on it.
    @Test func aSpeakerThatIsAlreadyOnKeepsItsInput() {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .bluetoothPaired)
        #expect(SpeakerSettings(powerOnInput: .optical).powerOnByte(from: on) == on)
    }
}
