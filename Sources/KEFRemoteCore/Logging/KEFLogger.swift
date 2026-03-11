import Foundation

/// Log severity levels for speaker communication.
public enum KEFLogLevel {
    /// Byte-level detail: hex dumps, raw protocol data.
    /// Useful when diagnosing unexpected responses or byte misalignment.
    case debug

    /// Operational events: connected, command sent, state changed.
    /// Safe to leave on in production — concise and meaningful.
    case info

    /// Failures: invalid response, connection lost, unexpected behaviour.
    case error
}

/// Log handler closure. Receives a severity level and a message string.
///
/// The default is a no-op. Pass a handler to `SpeakerController` and
/// `TCPSpeakerConnection` to enable logging.
///
/// In the app layer, back this with `os.Logger` so logs appear in Xcode
/// and in `log stream`/`log show` via the CLI.
///
/// Example wiring with `os.Logger`:
/// ```swift
/// let kefLog = Logger(subsystem: "com.kef-remote", category: "speaker")
/// let handler: KEFLogHandler = { level, message in
///     switch level {
///     case .debug: kefLog.debug("\(message, privacy: .public)")
///     case .info:  kefLog.info("\(message, privacy: .public)")
///     case .error: kefLog.error("\(message, privacy: .public)")
///     }
/// }
/// ```
///
/// CLI access (macOS unified logging):
/// ```bash
/// # Operational logs only (info and above)
/// log stream --predicate 'subsystem == "com.kef-remote"'
///
/// # Full detail including hex bytes
/// log stream --predicate 'subsystem == "com.kef-remote"' --level debug
/// ```
public typealias KEFLogHandler = (KEFLogLevel, String) -> Void
