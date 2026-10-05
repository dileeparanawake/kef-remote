import Foundation
import Network

/// Real TCP connection to a KEF speaker using Network.framework.
///
/// Connects to the speaker on port 50001. Sets TCP_NODELAY for
/// immediate command delivery. Connecting gives up after
/// ``connectTimeout`` and a reply after ``replyTimeout``, so an unplugged
/// speaker shows as unreachable within about 5 seconds, not after the
/// operating system's own TCP timeout (18 seconds in the 5 Oct live test).
///
/// This class is not used in tests — tests use MockSpeakerConnection.
public class TCPSpeakerConnection: SpeakerConnection {
    /// How long to wait for the speaker to accept a connection.
    public static let connectTimeout: Duration = .seconds(3)
    /// How long to wait for a reply. The speaker answers in about 0.1 s,
    /// so 2 s only runs out when it is gone.
    public static let replyTimeout: Duration = .seconds(2)

    private var connection: NWConnection?
    /// The speaker's IP, so the app can tell if discovery found the one it is on.
    public let host: String
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
    /// wait to batch them — critical for 3-4 byte commands). With no
    /// reply within ``replyTimeout`` it drops the connection and throws
    /// ``KEFError/commandTimeout``.
    public func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        let conn = try await getConnection()

        return try await withDeadline(Self.replyTimeout, onTimeout: { [weak self] in
            self?.drop(conn, reason: "no reply within \(Self.replyTimeout)")
        }) {
            try await Self.exchange(data, expectResponseBytes: expectResponseBytes, on: conn)
        }
    }

    /// Write the command, then read exactly `expectResponseBytes` back.
    private static func exchange(_ data: Data, expectResponseBytes: Int, on conn: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: KEFError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }

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

    /// Cancel a connection that stopped answering. Cancelling ends its
    /// pending read; the next command connects afresh.
    private func drop(_ conn: NWConnection, reason: String) {
        conn.cancel()
        if connection === conn { connection = nil }
        log(.error, "TCP: \(reason) from \(host):\(port); dropping the connection")
    }

    private func getConnection() async throws -> NWConnection {
        if let existing = connection, existing.state == .ready {
            return existing
        }

        // Configure TCP with NODELAY
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        tcpOptions.connectionTimeout = Int(Self.connectTimeout.components.seconds)

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
                    continuation.resume(throwing: KEFError(error))
                case .waiting(let error):
                    // A dead route (e.g. the speaker's old IP) waits here
                    // forever. Fail instead, so the app can rediscover.
                    conn?.stateUpdateHandler = nil
                    conn?.cancel()
                    self?.log(.error, "TCP: connection waiting — \(error.localizedDescription); giving up")
                    continuation.resume(throwing: KEFError(error))
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

extension KEFError {
    /// A connection error from Network.framework. A refusal gets its own
    /// case, so the check can try again rather than give up; so does a
    /// blocked Local Network, so the menu can name the setting.
    init(_ error: NWError) {
        if case .posix(.ECONNREFUSED) = error {
            self = .connectionRefused
        } else if case .posix(let code) = error, LocalNetworkPermission.deniedCodes.contains(code) {
            self = .localNetworkBlocked(error.localizedDescription)
        } else {
            self = .connectionFailed(error.localizedDescription)
        }
    }
}
