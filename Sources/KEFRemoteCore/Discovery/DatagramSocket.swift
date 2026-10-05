import Foundation

/// One UDP packet that arrived, and who sent it.
public struct Datagram: Equatable, Sendable {
    public let data: Data
    public let fromHost: String

    public init(data: Data, fromHost: String) {
        self.data = data
        self.fromHost = fromHost
    }
}

/// A UDP socket, so discovery can be tested without a network.
///
/// Tests use `MockDatagramSocket`; the app uses `BSDDatagramSocket`.
public protocol DatagramSocket: Sendable {
    func send(_ data: Data, toHost host: String, port: UInt16) throws

    /// The next datagram, or nil once the deadline passes.
    func receive(until deadline: ContinuousClock.Instant) async throws -> Datagram?

    func close()
}

/// Fetches a device's description.xml, so discovery can be tested without HTTP.
///
/// Tests use `MockDescriptionFetcher`; the app uses `URLSessionDescriptionFetcher`.
public protocol DescriptionFetcher: Sendable {
    func fetch(_ url: URL) async throws -> Data
}
