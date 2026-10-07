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

    @Test func whileBlockedItAsksMacOSAgain() {
        #expect(LocalNetworkRetry.tick(after: .localNetworkBlocked) == .probe)
    }

    /// A search or check is running (a retry, or Find speaker): its
    /// answer decides, so the tick lets it finish.
    @Test func whileAnAttemptRunsItWaits() {
        #expect(LocalNetworkRetry.tick(after: .searching) == .wait)
        #expect(LocalNetworkRetry.tick(after: .connecting) == .wait)
    }

    /// Any other answer means macOS let the app out: the speaker
    /// answered, or it's off, or the app left the home network.
    @Test func anyOtherAnswerStopsIt() {
        for status in [ConnectionStatus.connected, .notConnected, .noSpeaker, .dormant] {
            #expect(LocalNetworkRetry.tick(after: status) == .stop, "\(status)")
        }
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
