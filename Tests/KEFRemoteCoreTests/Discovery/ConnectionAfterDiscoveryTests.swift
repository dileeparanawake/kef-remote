import Testing
@testable import KEFRemoteCore

/// What happens to the live connection once discovery finds the speaker.
struct ConnectionAfterDiscoveryTests {

    /// Reconnecting to the same IP gets refused: a KEF takes one
    /// connection at a time, and the old one hasn't closed yet.
    @Test func alreadyConnectedToTheFoundIPKeepsTheConnection() {
        let next = ConnectionAfterDiscovery(foundIP: "192.168.1.80", connectedIP: "192.168.1.80")
        #expect(next == .keep)
    }

    @Test func aNewIPReconnects() {
        let next = ConnectionAfterDiscovery(foundIP: "192.168.1.80", connectedIP: "192.168.1.99")
        #expect(next == .reconnect)
    }

    @Test func noConnectionReconnects() {
        let next = ConnectionAfterDiscovery(foundIP: "192.168.1.80", connectedIP: nil)
        #expect(next == .reconnect)
    }
}
