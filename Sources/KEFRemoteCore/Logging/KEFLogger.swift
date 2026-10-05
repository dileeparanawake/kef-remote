import Foundation

/// Log severity levels for speaker communication.
public enum KEFLogLevel {
    /// Byte-level detail: hex dumps, raw protocol data.
    /// Useful when diagnosing unexpected responses or byte misalignment.
    case debug

    /// Operational events: connected, command sent, state changed.
    /// Safe to leave on in production — concise and meaningful.
    case info

    /// Something went wrong but the app carries on (a reply dropped, a retry).
    case warning

    /// Failures: invalid response, connection lost, unexpected behaviour.
    case error
}

/// Log handler closure. Receives a severity level and a message string.
///
/// `SpeakerController` and `TCPSpeakerConnection` take one (default:
/// no-op). The app passes a closure that forwards to its `AppLogger`,
/// which writes to os.Logger, stderr and the log file. Newer code takes
/// a ``KEFLog`` instead; ``HandlerLog`` bridges the two.
public typealias KEFLogHandler = (KEFLogLevel, String) -> Void
