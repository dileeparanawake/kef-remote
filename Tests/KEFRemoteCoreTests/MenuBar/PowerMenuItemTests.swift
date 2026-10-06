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
        #expect(item.isEnabled)
    }

    @Test func aSpeakerThatIsOffOffersToTurnItOn() {
        let item = PowerMenuItem(speakerSource: source(poweredOn: false), isConnected: true)
        #expect(item.title == "Turn speaker on")
        #expect(item.isEnabled)
    }

    /// Before the first read the app doesn't know which way it is.
    @Test func beforeTheFirstReadItSaysBoth() {
        let item = PowerMenuItem(speakerSource: nil, isConnected: true)
        #expect(item.title == "Turn speaker on/off")
        #expect(item.isEnabled)
    }

    /// Once the speaker stops answering, the last byte may be old (KEF's
    /// remote), and a click couldn't reach it anyway.
    @Test func notConnectedItIsGreyedAndSaysBoth() {
        let item = PowerMenuItem(speakerSource: source(poweredOn: true), isConnected: false)
        #expect(item.title == "Turn speaker on/off")
        #expect(!item.isEnabled)
    }
}
