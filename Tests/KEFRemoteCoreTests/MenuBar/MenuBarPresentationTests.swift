import Testing
@testable import KEFRemoteCore

struct MenuBarPresentationTests {

    @Test func afterACommandSucceedsTheIconIsAFilledSpeaker() {
        let shown = MenuBarPresentation(status: .ok, speakerName: "LSX", ip: "192.168.1.80")

        #expect(shown.symbolName == "hifispeaker.fill")
        #expect(shown.title == "Connected to LSX")
    }

    @Test func afterACommandFailsTheIconIsAWarningTriangle() {
        let shown = MenuBarPresentation(status: .error, speakerName: "LSX", ip: "192.168.1.80")

        #expect(shown.symbolName == "exclamationmark.triangle")
        #expect(shown.title == "Can't reach LSX")
    }

    @Test func beforeAnyCommandTheMenuShowsWhereTheSpeakerIs() {
        let shown = MenuBarPresentation(status: .ready, speakerName: "LSX", ip: "192.168.1.80")

        #expect(shown.symbolName == "hifispeaker")
        #expect(shown.title == "LSX at 192.168.1.80")
    }

    @Test func offTheHomeNetworkTheIconIsACrossedOutSpeaker() {
        let shown = MenuBarPresentation(status: .dormant, speakerName: "LSX", ip: "192.168.1.80")

        #expect(shown.symbolName == "speaker.slash")
        #expect(shown.title == "Paused: not on home network")
    }

    @Test func withNoSpeakerSetTheIconAsksForOne() {
        let shown = MenuBarPresentation(status: .noSpeaker, speakerName: nil, ip: nil)

        #expect(shown.symbolName == "hifispeaker.badge.plus")
        #expect(shown.title == "No speaker set")
    }

    @Test func whileDiscoveryRunsTheIconIsAMagnifyingGlass() {
        let shown = MenuBarPresentation(status: .searching, speakerName: nil, ip: nil)

        #expect(shown.symbolName == "magnifyingglass")
        #expect(shown.title == "Looking for the speaker…")
    }

    @Test func withNoSavedNameTheMenuSaysTheSpeaker() {
        #expect(MenuBarPresentation(status: .ok, speakerName: nil, ip: "192.168.1.80").title == "Connected to the speaker")
        #expect(MenuBarPresentation(status: .ready, speakerName: nil, ip: "192.168.1.80").title == "Speaker at 192.168.1.80")
    }

    @Test func voiceOverReadsTheAppNameAndTheStatusLine() {
        let shown = MenuBarPresentation(status: .error, speakerName: "LSX", ip: "192.168.1.80")

        #expect(shown.accessibilityLabel == "KEF Remote: Can't reach LSX")
    }
}
