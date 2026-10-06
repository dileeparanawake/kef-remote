import Foundation
import Testing
@testable import KEFRemoteCore

/// Hand test, 6 Oct: he allowed Local Network in System Settings, and the
/// guide still said Blocked, because nothing tried again. While it's
/// blocked, the app asks macOS every few seconds, and tries the speaker
/// again once a packet gets out.
struct LocalNetworkRetryTests {

    // MARK: - How often

    @Test func itAsksAgainEveryFiveSeconds() {
        #expect(LocalNetworkRetry.interval == .seconds(5))
    }

    // MARK: - Each tick, from the menu bar's status

    /// The setup window closed, or the row already green: the tick
    /// follows only the menu bar's status, as before.
    private func tick(_ status: ConnectionStatus) -> LocalNetworkRetry.Tick {
        LocalNetworkRetry.tick(after: status, localNetwork: .granted, setupOpen: false)
    }

    @Test func whileBlockedItAsksMacOSAgain() {
        #expect(tick(.localNetworkBlocked) == .probe)
        #expect(LocalNetworkRetry.tick(after: .localNetworkBlocked, localNetwork: .notGranted, setupOpen: true) == .probe)
    }

    /// A search or check is running (a retry, or Find speaker): its
    /// answer decides, so the tick lets it finish.
    @Test func whileAnAttemptRunsItWaits() {
        #expect(tick(.searching) == .wait)
        #expect(tick(.connecting) == .wait)
        #expect(LocalNetworkRetry.tick(after: .searching, localNetwork: .notCheckedYet, setupOpen: true) == .wait)
    }

    /// Any other answer means macOS let the app out: the speaker
    /// answered, or it's off, or the app left the home network.
    @Test func anyOtherAnswerStopsIt() {
        for status in [ConnectionStatus.connected, .notConnected, .noSpeaker, .dormant] {
            #expect(tick(status) == .stop, "\(status)")
        }
    }

    // MARK: - While the setup window is open

    /// Hand test round 7: he allowed Local Network in System Settings and
    /// the row stayed "Not checked yet", because only a blocked status
    /// asked macOS again. While the setup window is open and the row
    /// isn't green, each tick asks, so the row turns green by itself.
    @Test func whileSetupIsOpenARowThatIsNotGreenIsChecked() {
        for status in [ConnectionStatus.notConnected, .noSpeaker, .dormant] {
            #expect(LocalNetworkRetry.tick(after: status, localNetwork: .notCheckedYet, setupOpen: true) == .checkRow, "\(status)")
            #expect(LocalNetworkRetry.tick(after: status, localNetwork: .notGranted, setupOpen: true) == .checkRow, "\(status)")
        }
    }

    @Test func aGreenRowIsNotCheckedAgain() {
        #expect(LocalNetworkRetry.tick(after: .noSpeaker, localNetwork: .granted, setupOpen: true) == .stop)
    }

    @Test func withSetupClosedAnUncheckedRowWaitsForTheSpeaker() {
        #expect(LocalNetworkRetry.tick(after: .noSpeaker, localNetwork: .notCheckedYet, setupOpen: false) == .stop)
    }

    // MARK: - I've allowed it

    @Test func theRowOffersTheCheckUntilItIsGreen() {
        #expect(PermissionRow(.localNetwork, status: .notCheckedYet).offersAllowedCheck)
        #expect(PermissionRow(.localNetwork, status: .notGranted).offersAllowedCheck)
        #expect(!PermissionRow(.localNetwork, status: .granted).offersAllowedCheck)
    }

    /// Accessibility is read from macOS every second while the window is
    /// open, so it needs no button.
    @Test func accessibilityHasNoCheckButton() {
        #expect(!PermissionRow(.accessibility, status: .notGranted).offersAllowedCheck)
        #expect(PermissionRow.allowedCheckTitle == "I've allowed it")
    }

    /// What the click found, under the row. Allowed turns the row green.
    @Test func theClickSaysWhatItFound() {
        #expect(LocalNetworkProbe.Result.allowed.checkLine == "Checked: allowed")
        #expect(LocalNetworkProbe.Result.blocked.checkLine
            == "Checked: still blocked. Turn on KEF Remote under Local Network, then click again.")
        #expect(LocalNetworkProbe.Result.failed("bind failed").checkLine
            == "Couldn't check just now (bind failed). Click again in a moment.")
    }

    // MARK: - After asking macOS

    @Test func stillBlockedKeepsWaiting() {
        #expect(LocalNetworkRetry.afterProbe(.blocked, discovery: .auto) == .keepWaiting)
        #expect(LocalNetworkRetry.afterProbe(.blocked, discovery: .manual) == .keepWaiting)
    }

    @Test func onceAllowedAutoLooksForTheSpeakerAgain() {
        #expect(LocalNetworkRetry.afterProbe(.allowed, discovery: .auto) == .rediscover)
    }

    /// Manual never searches by itself: it checks the IP he typed.
    @Test func onceAllowedManualChecksTheSavedIPAgain() {
        #expect(LocalNetworkRetry.afterProbe(.allowed, discovery: .manual) == .reconnect)
    }

    /// Some other socket failure says nothing about the permission: the
    /// full attempt finds out, and the menu bar shows what it finds.
    @Test func anotherFailureTriesTheSpeakerToFindOut() {
        #expect(LocalNetworkRetry.afterProbe(.failed("bind failed"), discovery: .auto) == .rediscover)
        #expect(LocalNetworkRetry.afterProbe(.failed("bind failed"), discovery: .manual) == .reconnect)
    }

    // MARK: - The probe: one M-SEARCH, sent and not listened for

    @Test func theProbeSendsOneSearchAndCloses() {
        let socket = MockDatagramSocket()

        let result = LocalNetworkProbe(makeSocket: { socket }).run()

        #expect(result == .allowed)
        #expect(socket.sent == [.init(data: SSDPSearch.mediaRendererRequest,
                                      host: SSDPSearch.multicastHost, port: SSDPSearch.multicastPort)])
        #expect(socket.isClosed)
    }

    @Test func noRouteToHostMeansStillBlocked() {
        let socket = MockDatagramSocket()
        socket.sendError = SocketError("sendto", code: EHOSTUNREACH)

        #expect(LocalNetworkProbe(makeSocket: { socket }).run() == .blocked)
        #expect(socket.isClosed)
    }

    @Test func anotherSocketErrorIsAFailureWithItsReason() {
        let probe = LocalNetworkProbe(makeSocket: { throw SocketError("bind", code: EADDRINUSE) })

        #expect(probe.run() == .failed("bind failed: Address already in use (errno 48)"))
    }

    // MARK: - What the guide shows

    /// The packet got out, so the row turns green even if the speaker
    /// is off and can't answer yet.
    @Test func anAllowedProbeGrantsLocalNetwork() {
        #expect(PermissionStatus.notGranted.localNetwork(after: LocalNetworkProbe.Result.allowed) == .granted)
    }

    @Test func aBlockedProbeKeepsItBlocked() {
        #expect(PermissionStatus.notGranted.localNetwork(after: LocalNetworkProbe.Result.blocked) == .notGranted)
    }

    @Test func aFailedProbeSaysNothingAboutIt() {
        #expect(PermissionStatus.notGranted.localNetwork(after: LocalNetworkProbe.Result.failed("x")) == .notGranted)
    }
}
