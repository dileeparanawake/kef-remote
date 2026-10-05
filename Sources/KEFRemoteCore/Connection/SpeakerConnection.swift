import Foundation

/// Errors that can occur during speaker communication.
public enum KEFError: Error, Equatable {
    case connectionFailed(String)
    case commandTimeout
    case invalidResponse
    case notConnected
    case speakerUnreachable
}

extension KEFError {
    /// True when the speaker could not be reached, so it may have a new IP.
    /// False when it answered with something unexpected.
    public var isConnectionFailure: Bool {
        switch self {
        case .connectionFailed, .notConnected, .speakerUnreachable, .commandTimeout:
            return true
        case .invalidResponse:
            return false
        }
    }
}

/// Abstraction over the TCP connection to a KEF speaker.
///
/// This protocol exists so the command layer can be tested without
/// a real network connection. Tests use `MockSpeakerConnection`;
/// the app uses `TCPSpeakerConnection` (Network.framework).
public protocol SpeakerConnection {
    /// Send a command and wait for the response.
    ///
    /// - Parameters:
    ///   - data: The raw command bytes to send.
    ///   - expectResponseBytes: Exact number of bytes to read from the response.
    ///     GET responses are 5 bytes; SET responses are 3 bytes.
    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data
}
