import Testing
@testable import KEFRemoteCore

struct MenuBarPresentationTests {

    private func shown(
        _ status: ConnectionStatus,
        accessibility: PermissionStatus = .granted,
        name: String? = "LSX",
        ip: String? = "192.168.1.80",
        isFlashingConnected: Bool = false
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            status: status,
            accessibility: accessibility,
            speakerName: name,
            ip: ip,
            isFlashingConnected: isFlashingConnected
        )
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

    /// The second line points to the permissions guide, which opens the pane.
    @Test func whenLocalNetworkIsBlockedTheMenuSaysToAllowItInPermissions() {
        let blocked = shown(.localNetworkBlocked)

        #expect(blocked.title == "Can't reach LSX: allow Local Network in System Settings")
        #expect(blocked.detail == "Click Permissions… to open the setting")
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

    // MARK: - Accessibility off

    /// Hand test, 6 Oct: with Accessibility off the volume keys can't
    /// work, so the icon shows the red dot and the menu says what to do.
    @Test func withAccessibilityOffAConnectedSpeakerShowsTheRedDotAndSaysWhatToDo() {
        let keysOff = shown(.connected, accessibility: .notGranted)

        #expect(keysOff.needsAttention)
        #expect(keysOff.dot == .needsAttention)
        #expect(keysOff.title == "Volume keys off: allow Accessibility")
        #expect(keysOff.detail == "Click Permissions… to turn it on")
    }

    /// The shape still says the connection; the dot says he's needed.
    @Test func withAccessibilityOffTheIconKeepsTheConnectionShape() {
        #expect(shown(.connected, accessibility: .notGranted).isConnected)
        #expect(shown(.connected, accessibility: .notGranted).symbolName == "hifispeaker.fill")
        #expect(shown(.connecting, accessibility: .notGranted).symbolName == "hifispeaker")
        #expect(shown(.dormant, accessibility: .notGranted).symbolName == "speaker.slash")
    }

    /// Checking the speaker and being off the home network sort
    /// themselves out; Accessibility doesn't, so it takes the lines.
    @Test func withAccessibilityOffStatesThatSortThemselvesOutSayToAllowIt() {
        for status in [ConnectionStatus.connecting, .dormant] {
            let keysOff = shown(status, accessibility: .notGranted)
            #expect(keysOff.dot == .needsAttention, "\(status)")
            #expect(keysOff.title == "Volume keys off: allow Accessibility", "\(status)")
        }
    }

    /// A connection problem keeps its lines, so Find speaker under them
    /// still makes sense. The Permissions… item flags Accessibility.
    @Test func aConnectionThatNeedsHimKeepsItsLinesWhenAccessibilityIsOff() {
        for status in [ConnectionStatus.noSpeaker, .notConnected, .localNetworkBlocked] {
            #expect(shown(status, accessibility: .notGranted) == shown(status), "\(status)")
        }
    }

    /// He just asked it to look, so the orange pulse shows that it is.
    /// Once it finds the speaker, the red dot is back.
    @Test func whileFindingTheSpeakerTheSearchShowsEvenWithAccessibilityOff() {
        let searching = shown(.searching, accessibility: .notGranted)

        #expect(searching.dot == .searching)
        #expect(searching.detail == "Looking for the speaker…")
    }

    @Test func withAccessibilityOffTheGreenFlashGivesWayToTheRedDot() {
        #expect(shown(.connected, accessibility: .notGranted, isFlashingConnected: true).dot == .needsAttention)
        #expect(shown(.connected, isFlashingConnected: true).dot == .justConnected)
    }

    /// "Not checked yet" is a Local Network state; it never asks him
    /// for anything.
    @Test func onlyAccessibilityThatIsNotGrantedShowsTheDot() {
        #expect(!shown(.connected, accessibility: .notCheckedYet).needsAttention)
        #expect(!shown(.connected, accessibility: .granted).needsAttention)
    }

    @Test func findSpeakerDoesNotDependOnAccessibility() {
        let all: [ConnectionStatus] = [.dormant, .noSpeaker, .searching, .connecting, .connected, .notConnected, .localNetworkBlocked]
        for status in all {
            #expect(shown(status, accessibility: .notGranted).offersFindSpeaker == shown(status).offersFindSpeaker, "\(status)")
        }
    }
}
