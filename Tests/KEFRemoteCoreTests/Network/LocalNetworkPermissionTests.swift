import Testing
import Foundation
import Network
@testable import KEFRemoteCore

/// macOS answers "No route to host" or "Network is down" when KEF Remote
/// isn't allowed on the local network. The menu bar names that setting.
struct LocalNetworkPermissionTests {

    @Test func noRouteToHostFromDiscoveryMeansLocalNetworkIsBlocked() {
        #expect(LocalNetworkPermission.isDenied(by: SocketError("sendto", code: EHOSTUNREACH)))
    }

    @Test func networkIsDownFromDiscoveryMeansLocalNetworkIsBlocked() {
        #expect(LocalNetworkPermission.isDenied(by: SocketError("sendto", code: ENETDOWN)))
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

    @Test func noRouteToHostOnTCPBecomesLocalNetworkBlocked() {
        let error = NWError.posix(.EHOSTUNREACH)
        #expect(KEFError(error) == .localNetworkBlocked(error.localizedDescription))
    }
}
