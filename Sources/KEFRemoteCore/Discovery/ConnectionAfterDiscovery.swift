import Foundation

/// What to do with the live connection once discovery has found the speaker.
public enum ConnectionAfterDiscovery: Equatable, Sendable {
    /// Already on the IP discovery found: keep the connection. Dropping it
    /// and reconnecting at once gets refused, since a KEF takes one
    /// connection at a time.
    case keep
    /// A new IP, or no connection yet: connect to the IP discovery found.
    case reconnect

    /// - Parameters:
    ///   - foundIP: The IP discovery found.
    ///   - connectedIP: The IP of the connection the app holds, if any.
    public init(foundIP: String?, connectedIP: String?) {
        self = foundIP != nil && foundIP == connectedIP ? .keep : .reconnect
    }
}
