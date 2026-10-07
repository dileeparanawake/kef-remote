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
    @Test func theChoicesAreSavedByName() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(SpeakerSettings(powerOnInput: .optical, standby: .sixtyMinutes))
        #expect(String(decoding: data, as: UTF8.self) == #"{"powerOnInput":"optical","standby":"sixtyMinutes"}"#)
    }

    /// A file saved before the standby choice existed has only the input.
    @Test func settingsWithoutAStandbyChoiceLoadAsDontChange() throws {
        let json = #"{"powerOnInput":"usb"}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SpeakerSettings.self, from: json)
        #expect(settings == SpeakerSettings(powerOnInput: .usb, standby: .dontChange))
    }

    // MARK: - Standby choice

    @Test func standbyIsDontChangeByDefault() {
        #expect(SpeakerSettings().standby == .dontChange)
    }

    @Test func eachStandbyChoiceNamesTheTimeItWrites() {
        #expect(StandbyChoice.dontChange.mode == nil)
        #expect(StandbyChoice.twentyMinutes.mode == .twentyMinutes)
        #expect(StandbyChoice.sixtyMinutes.mode == .sixtyMinutes)
        #expect(StandbyChoice.never.mode == .never)
    }

    @Test func theStandbyChoicesAreListedInSettingsOrder() {
        #expect(StandbyChoice.allCases.map(\.label) == ["Don't change", "20 min", "60 min", "Never"])
    }

    // MARK: - Which standby time to write, and when

    @Test func choosingAndConnectingWriteTheChosenTime() {
        let settings = SpeakerSettings(standby: .sixtyMinutes)
        #expect(settings.standbyToWrite(for: .chosen) == .sixtyMinutes)
        #expect(settings.standbyToWrite(for: .connect) == .sixtyMinutes)
    }

    @Test func dontChangeWritesNothingWhenChosenOrOnConnect() {
        #expect(SpeakerSettings().standbyToWrite(for: .chosen) == nil)
        #expect(SpeakerSettings().standbyToWrite(for: .connect) == nil)
    }

    /// Dynamic standby: awake, the speaker uses the chosen time.
    @Test func wakeWritesTheChosenTime() {
        #expect(SpeakerSettings(standby: .twentyMinutes).standbyToWrite(for: .wake) == .twentyMinutes)
        #expect(SpeakerSettings(standby: .sixtyMinutes).standbyToWrite(for: .wake) == .sixtyMinutes)
    }

    /// With no choice, wake keeps what dynamic standby always did: never.
    @Test func wakeWithDontChangeStillWritesNever() {
        #expect(SpeakerSettings().standbyToWrite(for: .wake) == .never)
    }

    /// The sleep timer always asks for 20 min, so a speaker left on while
    /// the Mac sleeps goes to standby by itself, whatever was chosen.
    @Test func sleepAlwaysWritesTwentyMinutes() {
        for choice in StandbyChoice.allCases {
            #expect(SpeakerSettings(standby: choice).standbyToWrite(for: .sleep) == .twentyMinutes)
        }
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

    @Test func aChosenStandbyTimeGoesInWithThePowerBit() {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .wifi)
        let byte = SpeakerSettings(powerOnInput: .optical, standby: .twentyMinutes).powerOnByte(from: off)
        #expect(byte == SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .optical))
    }

    @Test func dontChangeKeepsTheSpeakersStandbyTime() {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .wifi)
        #expect(SpeakerSettings(powerOnInput: .usb).powerOnByte(from: off).standby == .sixtyMinutes)
    }

    /// Waking the Mac after a short sleep powers on a speaker that never
    /// went off: someone may be listening to another input on it.
    @Test func aSpeakerThatIsAlreadyOnKeepsItsInput() {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .bluetoothPaired)
        #expect(SpeakerSettings(powerOnInput: .optical).powerOnByte(from: on) == on)
    }

    /// The standby time is the owner's choice whenever the speaker is on,
    /// so an already-on speaker still gets it.
    @Test func aSpeakerThatIsAlreadyOnStillGetsTheChosenStandby() {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        let byte = SpeakerSettings(powerOnInput: .optical, standby: .sixtyMinutes).powerOnByte(from: on)
        #expect(byte == on.with(standby: .sixtyMinutes))
    }
}
