import Foundation
import Network

/// Result of parsing an SSDP response.
public struct SSDPResult: Sendable {
    public let location: String
    public let ip: String

    public init(location: String, ip: String) {
        self.location = location
        self.ip = ip
    }
}

/// Thread-safe collector for SSDP discovery results.
private final class SSDPResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [SSDPResult] = []
    private var hasResumed = false

    func append(_ result: SSDPResult) {
        lock.lock()
        results.append(result)
        lock.unlock()
    }

    func collect() -> [SSDPResult] {
        lock.lock()
        let collected = results
        lock.unlock()
        return collected
    }

    /// Ensure the continuation is only resumed once. Returns true if this
    /// call was the first to resume; false if already resumed.
    func tryResume() -> Bool {
        lock.lock()
        guard !hasResumed else {
            lock.unlock()
            return false
        }
        hasResumed = true
        lock.unlock()
        return true
    }
}

/// Discovers KEF speakers on the local network using SSDP/UPnP multicast.
///
/// KEF speakers advertise as UPnP MediaRenderer devices. We send an
/// M-SEARCH multicast to 239.255.255.250:1900 and look for responses
/// containing MediaRenderer in the ST (search target) header.
///
/// Reference: Perl `kefctl` uses Net::UPnP::ControlPoint for discovery.
public enum SSDPDiscovery {

    /// The SSDP multicast address and port.
    public static let multicastAddress = "239.255.255.250"
    public static let multicastPort: UInt16 = 1900

    /// The M-SEARCH request to find UPnP root devices.
    public static let searchRequest =
        "M-SEARCH * HTTP/1.1\r\n"
        + "HOST: 239.255.255.250:1900\r\n"
        + "MAN: \"ssdp:discover\"\r\n"
        + "MX: 3\r\n"
        + "ST: upnp:rootdevice\r\n"
        + "\r\n"

    /// Parse an SSDP response to extract the LOCATION URL and IP address.
    /// Returns nil if the response doesn't contain a LOCATION header.
    public static func parseResponse(_ response: String) -> SSDPResult? {
        let lines = response.components(separatedBy: "\r\n")
        var location: String?

        for line in lines {
            let lowered = line.lowercased()
            if lowered.hasPrefix("location:") {
                location = String(line.dropFirst("location:".count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        guard let loc = location,
              let url = URL(string: loc),
              let host = url.host else {
            return nil
        }

        return SSDPResult(location: loc, ip: host)
    }

    /// Discover speakers on the local network. Returns IPs of devices that respond.
    /// Timeout controls how long to wait for responses (seconds).
    ///
    /// Note: This uses UDP multicast, which requires network access.
    /// Not unit-testable — tested during manual hardware verification.
    public static func discover(timeout: TimeInterval = 3) async throws -> [SSDPResult] {
        let host = NWEndpoint.Host(multicastAddress)
        guard let port = NWEndpoint.Port(rawValue: multicastPort) else {
            throw KEFError.connectionFailed("Invalid SSDP port")
        }

        let connection = NWConnection(
            host: host,
            port: port,
            using: .udp
        )

        let collector = SSDPResultCollector()

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Send M-SEARCH request
                    let data = Self.searchRequest.data(using: .utf8)!
                    connection.send(
                        content: data,
                        completion: .contentProcessed { error in
                            if let error {
                                if collector.tryResume() {
                                    continuation.resume(throwing:
                                        KEFError.connectionFailed(error.localizedDescription)
                                    )
                                }
                                return
                            }
                            // Start receiving responses
                            Self.startReceiving(connection: connection, collector: collector)
                        }
                    )
                case .failed(let error):
                    if collector.tryResume() {
                        continuation.resume(throwing:
                            KEFError.connectionFailed(error.localizedDescription)
                        )
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Wait for timeout, then collect results
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                if collector.tryResume() {
                    continuation.resume(returning: collector.collect())
                }
            }
        }
    }

    /// Continuously receive UDP responses on the connection.
    private static func startReceiving(
        connection: NWConnection,
        collector: SSDPResultCollector
    ) {
        connection.receiveMessage { content, _, _, error in
            if let content,
               let responseString = String(data: content, encoding: .utf8),
               let result = parseResponse(responseString)
            {
                collector.append(result)
            }
            // Keep receiving until the connection is cancelled
            if error == nil {
                startReceiving(connection: connection, collector: collector)
            }
        }
    }
}
