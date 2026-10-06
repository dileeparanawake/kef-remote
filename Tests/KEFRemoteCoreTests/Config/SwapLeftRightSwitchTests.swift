import Testing
@testable import KEFRemoteCore

/// The Swap left and right switch in Settings: what it shows, when it
/// can be used, and what it says when the speaker didn't take it.
struct SwapLeftRightSwitchTests {

    private let normal = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
    private var swapped: SourceByte { normal.with(isInversed: true) }

    @Test func itShowsTheSpeakersState() {
        #expect(SwapLeftRightSwitch(speakerSource: swapped, isConnected: true, requested: nil).isOn)
        #expect(!SwapLeftRightSwitch(speakerSource: normal, isConnected: true, requested: nil).isOn)
    }

    @Test func itCanBeUsedWhileConnected() {
        #expect(SwapLeftRightSwitch(speakerSource: normal, isConnected: true, requested: nil).isEnabled)
    }

    /// The last byte read may be stale once the speaker stops answering.
    @Test func whenNotConnectedItIsGreyedOutAndOff() {
        let shown = SwapLeftRightSwitch(speakerSource: swapped, isConnected: false, requested: nil)
        #expect(!shown.isEnabled)
        #expect(!shown.isOn)
    }

    @Test func beforeTheFirstReadItIsGreyedOut() {
        #expect(!SwapLeftRightSwitch(speakerSource: nil, isConnected: true, requested: nil).isEnabled)
    }

    /// It moves when clicked, not when the speaker acks, and can't be
    /// clicked again until the write is done.
    @Test func whileWritingItShowsTheRequestAndWaits() {
        let shown = SwapLeftRightSwitch(speakerSource: normal, isConnected: true, requested: true)
        #expect(shown.isOn)
        #expect(!shown.isEnabled)
    }

    @Test func aSpeakerThatCanNotBeReachedIsNamed() {
        #expect(SwapLeftRightSwitch.failureNote(KEFError.commandTimeout)
            == "Not changed: can't reach the speaker")
    }

    @Test func aBadReplySaysTheSpeakerDidNotTakeIt() {
        #expect(SwapLeftRightSwitch.failureNote(KEFError.invalidResponse)
            == "Not changed: the speaker didn't take it")
    }
}
