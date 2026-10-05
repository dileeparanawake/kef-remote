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

    // MARK: - Red dot

    /// Live test, 5 Oct: he wants to see at a glance that something
    /// needs him, without opening the menu.
    @Test func statesThatNeedHimShowTheRedDot() {
        for status in [ConnectionStatus.noSpeaker, .notConnected, .localNetworkBlocked] {
            #expect(shown(status).needsAttention, "\(status)")
        }
    }

    /// Connected, checking, searching and off the home network all sort
    /// themselves out, so they show no dot.
    @Test func statesThatSortThemselvesOutShowNoDot() {
        for status in [ConnectionStatus.connected, .connecting, .searching, .dormant] {
            #expect(!shown(status).needsAttention, "\(status)")
        }
    }

    /// The dot sits bottom-right, where a symbol's badge would be, so a
    /// state with a dot uses the plain speaker.
    @Test func aStateWithTheDotUsesThePlainSpeakerSoNoBadgeIsHidden() {
        for status in [ConnectionStatus.noSpeaker, .notConnected, .localNetworkBlocked] {
            #expect(shown(status).symbolName == "hifispeaker", "\(status)")
        }
    }

    // MARK: - Needs him: the first line says what's wrong and what to do

    @Test func whenTheSpeakerCannotBeReachedTheMenuSaysToFindIt() {
        let failed = shown(.notConnected)

        #expect(failed.title == "Can't reach LSX: click Find speaker")
        #expect(failed.detail == "No answer at 192.168.1.80")
        #expect(failed.offersFindSpeaker)
    }

    @Test func whenLocalNetworkIsBlockedTheMenuSaysToAllowIt() {
        let blocked = shown(.localNetworkBlocked)

        #expect(blocked.title == "Can't reach LSX: allow Local Network in System Settings")
        #expect(blocked.detail == "Privacy & Security > Local Network > KEF Remote")
        #expect(blocked.offersFindSpeaker)
    }

    @Test func withNoSpeakerSetTheMenuSaysToFindOne() {
        let none = shown(.noSpeaker, name: nil, ip: nil)

        #expect(none.title == "No speaker set: click Find speaker")
        #expect(none.detail == "Or type its IP in Settings…")
        #expect(none.offersFindSpeaker)
    }

    @Test func withNoSavedNameOrIPTheLinesStillRead() {
        #expect(shown(.notConnected, name: nil, ip: nil).title == "Can't reach the speaker: click Find speaker")
        #expect(shown(.notConnected, name: nil, ip: nil).detail == "No answer at no IP")
        #expect(shown(.localNetworkBlocked, name: nil).title == "Can't reach the speaker: allow Local Network in System Settings")
    }

    // MARK: - Sorts itself out

    @Test func everyStateWithoutTheDotOrConnectionSaysNotConnected() {
        for status in [ConnectionStatus.dormant, .searching, .connecting] {
            #expect(!shown(status).isConnected)
            #expect(shown(status).title == "Not connected")
        }
    }

    @Test func whileCheckingTheSpeakerTheIconIsAnOutline() {
        let checking = shown(.connecting)

        #expect(checking.symbolName == "hifispeaker")
        #expect(checking.detail == "Checking LSX at 192.168.1.80…")
        #expect(checking.offersFindSpeaker)
    }

    @Test func whileDiscoveryRunsThereIsNoSecondFindItem() {
        let searching = shown(.searching, name: nil, ip: nil)

        #expect(searching.detail == "Looking for the speaker…")
        #expect(!searching.offersFindSpeaker)
    }

    /// Round 3, 5 Oct: the speaker stays while it looks (no icon swap);
    /// the pulsing orange dot says it's looking.
    @Test func whileFindingTheSpeakerTheIconStaysASpeaker() {
        let searching = shown(.searching, name: nil, ip: nil)

        #expect(searching.symbolName == "hifispeaker")
        #expect(searching.dot == .searching)
        #expect(!searching.needsAttention)
    }

    @Test func offTheHomeNetworkTheIconIsACrossedOutSpeakerAndFindIsHidden() {
        let paused = shown(.dormant)

        #expect(paused.symbolName == "speaker.slash")
        #expect(paused.detail == "Paused: not on home network")
        #expect(!paused.offersFindSpeaker)
    }

    // MARK: - VoiceOver

    @Test func voiceOverReadsTheAppNameAndBothLines() {
        #expect(shown(.notConnected).accessibilityLabel == "KEF Remote: Can't reach LSX: click Find speaker. No answer at 192.168.1.80")
        #expect(shown(.connected).accessibilityLabel == "KEF Remote: Connected to LSX. 192.168.1.80")
    }
}
