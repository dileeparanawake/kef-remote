import Testing
@testable import KEFRemoteCore

/// Turn speaker on / off in the menu: its words come from the last
/// source byte, and it works only while connected.
struct PowerMenuItemTests {
    private func source(poweredOn: Bool) -> SourceByte {
        SourceByte(isPoweredOn: poweredOn, isInversed: false, standby: .sixtyMinutes, input: .optical)
    }

    @Test func aSpeakerThatIsOnOffersToTurnItOff() {
        let item = PowerMenuItem(speakerSource: source(poweredOn: true), isConnected: true)
        #expect(item.title == "Turn speaker off")
        #expect(item.action == .turnOff)
        #expect(item.isEnabled)
    }

    @Test func aSpeakerThatIsOffOffersToTurnItOn() {
        let item = PowerMenuItem(speakerSource: source(poweredOn: false), isConnected: true)
        #expect(item.title == "Turn speaker on")
        #expect(item.action == .turnOn)
        #expect(item.isEnabled)
    }

    /// Before the first read the app doesn't know which way it is, so a
    /// click flips whatever it reads.
    @Test func beforeTheFirstReadItSaysBothAndToggles() {
        let item = PowerMenuItem(speakerSource: nil, isConnected: true)
        #expect(item.title == "Turn speaker on/off")
        #expect(item.action == .toggle)
        #expect(item.isEnabled)
    }

    /// Once the speaker stops answering, the last byte may be old (KEF's
    /// remote), and a click couldn't reach it anyway.
    @Test func notConnectedItIsGreyedAndSaysBoth() {
        let item = PowerMenuItem(speakerSource: source(poweredOn: true), isConnected: false)
        #expect(item.title == "Turn speaker on/off")
        #expect(item.action == .toggle)
        #expect(!item.isEnabled)
    }

    // MARK: - What a click does, from the byte read at the click

    @Test func turnOffTurnsOffASpeakerThatIsOn() {
        #expect(PowerMenuAction.turnOff.step(isPoweredOn: true) == .powerOff)
    }

    /// The label said on, but it went off meanwhile (KEF's remote): do
    /// what the label says, which is nothing.
    @Test func turnOffLeavesASpeakerThatIsAlreadyOff() {
        #expect(PowerMenuAction.turnOff.step(isPoweredOn: false) == .alreadyOff)
    }

    @Test func turnOnTurnsOnASpeakerThatIsOff() {
        #expect(PowerMenuAction.turnOn.step(isPoweredOn: false) == .powerOn)
    }

    /// Writing power on to a speaker that is on would switch it to the
    /// Input on turn-on choice, which he didn't ask for.
    @Test func turnOnLeavesASpeakerThatIsAlreadyOn() {
        #expect(PowerMenuAction.turnOn.step(isPoweredOn: true) == .alreadyOn)
    }

    @Test func toggleFlipsEitherWay() {
        #expect(PowerMenuAction.toggle.step(isPoweredOn: true) == .powerOff)
        #expect(PowerMenuAction.toggle.step(isPoweredOn: false) == .powerOn)
    }
}
