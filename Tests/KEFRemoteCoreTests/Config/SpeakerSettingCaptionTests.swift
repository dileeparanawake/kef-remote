import Testing
@testable import KEFRemoteCore

/// Each speaker setting in Settings says, under its row, when it applies:
/// they apply at different times, and one shared caption read as if all
/// were turn-on defaults.
struct SpeakerSettingCaptionTests {

    @Test func inputOnTurnOnAppliesWhenTheAppTurnsTheSpeakerOn() {
        #expect(PowerOnInput.settingsCaption == "When KEF Remote turns the speaker on.")
    }

    @Test func standbyAppliesNowAndOnEachConnect() {
        #expect(StandbyChoice.settingsCaption == "Now, and each time KEF Remote connects.")
    }

    @Test func swapAppliesNowAndTheSpeakerKeepsIt() {
        #expect(SwapLeftRightSwitch.settingsCaption == "Now. The speaker remembers it.")
    }
}
