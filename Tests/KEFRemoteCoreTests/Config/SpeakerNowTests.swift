import Testing
@testable import KEFRemoteCore

/// Settings › Speaker shows what the speaker is set to now, so Don't
/// change doesn't hide it (hand test round 6: after changing left and
/// right in KEF's app, he couldn't tell which way it was).
struct SpeakerNowTests {

    private let byte = SourceByte(isPoweredOn: true, isInversed: true, standby: .sixtyMinutes, input: .optical)

    // MARK: - Standby

    @Test func dontChangeSaysTheSpeakersStandbyTime() {
        let now = SpeakerNow(speakerSource: byte, isConnected: true)
        #expect(now.label(for: StandbyChoice.dontChange) == "Don't change (now 60 min)")
    }

    /// Only Don't change needs it: the other choices are the value.
    @Test func theOtherStandbyChoicesKeepTheirNames() {
        let now = SpeakerNow(speakerSource: byte, isConnected: true)
        #expect(now.label(for: StandbyChoice.twentyMinutes) == "20 min")
        #expect(now.label(for: StandbyChoice.never) == "Never")
    }

    // MARK: - Input on turn-on

    @Test func dontChangeSaysTheSpeakersInput() {
        let now = SpeakerNow(speakerSource: byte, isConnected: true)
        #expect(now.label(for: PowerOnInput.dontChange) == "Don't change (now Optical)")
        #expect(now.label(for: PowerOnInput.wifi) == "Wi-Fi")
    }

    /// Either Bluetooth code reads as one input.
    @Test func bluetoothReadsTheSameEitherCode() {
        let unpaired = SpeakerNow(speakerSource: byte.with(input: .bluetoothUnpaired), isConnected: true)
        #expect(unpaired.label(for: PowerOnInput.dontChange) == "Don't change (now Bluetooth)")
    }

    // MARK: - Swap left and right

    @Test func swapSaysWhichWayTheSpeakerIs() {
        #expect(SpeakerNow(speakerSource: byte, isConnected: true).swapCaption == "Now: swapped")
        #expect(SpeakerNow(speakerSource: byte.with(isInversed: false), isConnected: true).swapCaption == "Now: normal")
    }

    // MARK: - Not known

    /// Once the speaker stops answering, the last byte may be stale (KEF's
    /// app can change it), so nothing claims what it is now.
    @Test func notConnectedShowsNoValue() {
        let now = SpeakerNow(speakerSource: byte, isConnected: false)
        #expect(now.label(for: StandbyChoice.dontChange) == "Don't change")
        #expect(now.label(for: PowerOnInput.dontChange) == "Don't change")
        #expect(now.swapCaption == "Not connected")
    }

    @Test func connectedButNotReadYetSaysSo() {
        let now = SpeakerNow(speakerSource: nil, isConnected: true)
        #expect(now.label(for: StandbyChoice.dontChange) == "Don't change")
        #expect(now.swapCaption == "Not read yet")
    }
}
