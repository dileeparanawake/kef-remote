import Foundation
import Network

/// Real TCP connection to a KEF speaker using Network.framework.
///
/// Connects to the speaker on port 50001. Sets TCP_NODELAY for
/// immediate command delivery. Connection and read timeouts are 3 seconds.
///
/// This class is not used in tests — tests use MockSpeakerConnection.
public class TCPSpeakerConnection: SpeakerConnection {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16
    private let log: KEFLogHandler

    public init(host: String, port: UInt16 = 50001, log: @escaping KEFLogHandler = { _, _ in }) {
        self.host = host
        self.port = port
        self.log = log
    }

    /// Send a command and wait for the response.
    ///
    /// Opens a connection if not already connected. Sets TCP_NODELAY
    /// to disable Nagle's algorithm (send bytes immediately, don't
    /// wait to batch them — critical for 3-4 byte commands).
    public func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        let conn = try await getConnection()

        // Send the command
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: KEFError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }

        // Receive the response (read exactly the expected number of bytes)
        return try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: expectResponseBytes, maximumLength: expectResponseBytes) { content, _, _, error in
                if let error {
                    continuation.resume(throwing: KEFError.connectionFailed(error.localizedDescription))
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: KEFError.invalidResponse)
                }
            }
        }
    }

    /// Disconnect from the speaker.
    public func disconnect() {
        connection?.cancel()
        connection = nil
        log(.info, "TCP: disconnected from \(host):\(port)")
    }

    // MARK: - Private

    private func getConnection() async throws -> NWConnection {
        if let existing = connection, existing.state == .ready {
            return existing
        }

        // Configure TCP with NODELAY
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        tcpOptions.connectionTimeout = 3

        let params = NWParameters(tls: nil, tcp: tcpOptions)
        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )

        log(.info, "TCP: connecting to \(host):\(port)")

        // Wait for connection to be ready
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { [weak conn, weak self] state in
                switch state {
                case .ready:
                    conn?.stateUpdateHandler = nil
                    self?.log(.info, "TCP: connected to \(self?.host ?? ""):\(self?.port ?? 0)")
                    continuation.resume()
                case .failed(let error):
                    conn?.stateUpdateHandler = nil
                    self?.log(.error, "TCP: connection failed — \(error.localizedDescription)")
                    continuation.resume(throwing: KEFError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    conn?.stateUpdateHandler = nil
                    self?.log(.error, "TCP: connection cancelled")
                    continuation.resume(throwing: KEFError.notConnected)
                default:
                    break
                }
            }
            conn.start(queue: .global())
        }

        self.connection = conn
        return conn
    }
}
