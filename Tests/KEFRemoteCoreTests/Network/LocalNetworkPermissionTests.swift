import Testing
import Foundation
import Network
@testable import KEFRemoteCore

/// macOS answers "No route to host", "Network is unreachable" or "Network
/// is down" when KEF Remote isn't allowed on the local network. The menu
/// bar names that setting.
struct LocalNetworkPermissionTests {

    @Test func noRouteToHostFromDiscoveryMeansLocalNetworkIsBlocked() {
        #expect(LocalNetworkPermission.isDenied(by: SocketError("sendto", code: EHOSTUNREACH)))
    }

    @Test func networkIsDownFromDiscoveryMeansLocalNetworkIsBlocked() {
        #expect(LocalNetworkPermission.isDenied(by: SocketError("sendto", code: ENETDOWN)))
    }

    /// Hand test round 7: with Local Network switched off, discovery's
    /// `sendto` failed with errno 51, the setting wasn't named, and the
    /// guide's row stayed "Not checked yet".
    @Test func networkIsUnreachableFromDiscoveryMeansLocalNetworkIsBlocked() {
        let error = SocketError("sendto", code: ENETUNREACH)
        #expect(error.description == "sendto failed: Network is unreachable (errno 51)")
        #expect(LocalNetworkPermission.isDenied(by: error))
    }

    @Test func networkIsUnreachableNamesTheSettingInTheDiscoveryResult() {
        let outcome = DiscoveryOutcome.failure(SocketError("sendto", code: ENETUNREACH))
        #expect(outcome.message.hasSuffix("Allow KEF Remote in System Settings > Privacy & Security > Local Network."))
    }

    /// The probe reads the same error as blocked, so the row turns red.
    @Test func networkIsUnreachableMakesTheProbeSayBlocked() {
        let socket = MockDatagramSocket()
        socket.sendError = SocketError("sendto", code: ENETUNREACH)
        #expect(LocalNetworkProbe(makeSocket: { socket }).run() == .blocked)
    }

    @Test func otherSocketErrorsAreNotAPermission() {
        #expect(!LocalNetworkPermission.isDenied(by: SocketError("bind", code: EADDRINUSE)))
    }

    @Test func aBlockedTCPConnectionIsAPermission() {
        #expect(LocalNetworkPermission.isDenied(by: KEFError.localNetworkBlocked("Network is down")))
    }

    @Test func aTimeoutIsNotAPermission() {
        #expect(!LocalNetworkPermission.isDenied(by: KEFError.connectionFailed("timed out")))
        #expect(!LocalNetworkPermission.isDenied(by: KEFError.commandTimeout))
    }

    // MARK: - TCP errors from Network.framework

    @Test func networkIsDownOnTCPBecomesLocalNetworkBlocked() {
        let error = NWError.posix(.ENETDOWN)
        #expect(KEFError(error) == .localNetworkBlocked(error.localizedDescription))
    }

    @Test func networkIsUnreachableOnTCPBecomesLocalNetworkBlocked() {
        let error = NWError.posix(.ENETUNREACH)
        #expect(KEFError(error) == .localNetworkBlocked(error.localizedDescription))
    }

    @Test func noRouteToHostOnTCPBecomesLocalNetworkBlocked() {
        let error = NWError.posix(.EHOSTUNREACH)
        #expect(KEFError(error) == .localNetworkBlocked(error.localizedDescription))
    }
}
