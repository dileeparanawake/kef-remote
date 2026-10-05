import Testing
@testable import KEFRemoteCore

struct MenuBarPresentationTests {

    private func shown(_ status: ConnectionStatus, name: String? = "LSX", ip: String? = "192.168.1.80") -> MenuBarPresentation {
        MenuBarPresentation(status: status, speakerName: name, ip: ip)
    }

    // MARK: - Connected

    @Test func whenConnectedTheIconIsAFilledSpeakerAndTheMenuSaysSo() {
        let connected = shown(.connected)

        #expect(connected.isConnected)
        #expect(connected.symbolName == "hifispeaker.fill")
        #expect(connected.title == "Connected to LSX")
        #expect(connected.detail == "192.168.1.80")
        #expect(!connected.offersFindSpeaker)
    }

    @Test func withNoSavedNameConnectedSaysTheSpeaker() {
        #expect(shown(.connected, name: nil).title == "Connected to the speaker")
    }

    // MARK: - Not connected

    @Test func everyOtherStatusSaysNotConnectedOnTheFirstLine() {
        for status in [ConnectionStatus.dormant, .noSpeaker, .searching, .connecting, .notConnected] {
            #expect(!shown(status).isConnected)
            #expect(shown(status).title == "Not connected")
        }
    }

    @Test func whenTheSpeakerCannotBeReachedTheIconHasAWarningBadge() {
        let failed = shown(.notConnected)

        #expect(failed.symbolName == "hifispeaker.badge.exclamationmark")
        #expect(failed.detail == "Can't reach LSX at 192.168.1.80")
        #expect(failed.offersFindSpeaker)
    }

    @Test func whileCheckingTheSpeakerTheIconIsAnOutline() {
        let checking = shown(.connecting)

        #expect(checking.symbolName == "hifispeaker")
        #expect(checking.detail == "Checking LSX at 192.168.1.80…")
        #expect(checking.offersFindSpeaker)
    }

    @Test func withNoSpeakerSetTheIconAsksForOne() {
        let none = shown(.noSpeaker, name: nil, ip: nil)

        #expect(none.symbolName == "hifispeaker.badge.plus")
        #expect(none.detail == "No speaker set")
        #expect(none.offersFindSpeaker)
    }

    @Test func whileDiscoveryRunsThereIsNoSecondFindItem() {
        let searching = shown(.searching, name: nil, ip: nil)

        #expect(searching.symbolName == "magnifyingglass")
        #expect(searching.detail == "Looking for the speaker…")
        #expect(!searching.offersFindSpeaker)
    }

    @Test func offTheHomeNetworkTheIconIsACrossedOutSpeakerAndFindIsHidden() {
        let paused = shown(.dormant)

        #expect(paused.symbolName == "speaker.slash")
        #expect(paused.detail == "Paused: not on home network")
        #expect(!paused.offersFindSpeaker)
    }

    @Test func withNoSavedNameOrIPTheDetailStillReads() {
        #expect(shown(.notConnected, name: nil, ip: nil).detail == "Can't reach the speaker at no IP")
    }

    // MARK: - VoiceOver

    @Test func voiceOverReadsTheAppNameAndBothLines() {
        #expect(shown(.notConnected).accessibilityLabel == "KEF Remote: Not connected. Can't reach LSX at 192.168.1.80")
        #expect(shown(.connected).accessibilityLabel == "KEF Remote: Connected to LSX. 192.168.1.80")
    }
}
