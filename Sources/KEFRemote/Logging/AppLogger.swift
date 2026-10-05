import Foundation
import KEFRemoteCore
import os

/// Triple-output logger for KEF Remote.
///
/// Every log message is written to three destinations simultaneously:
/// 1. **os.Logger** — Apple's unified logging system. Works with `log stream`
///    and `log show` when the app runs standalone (outside Xcode).
/// 2. **stderr** — Always appears in Xcode's debug console. Filter using
///    the text filter bar (type a category, level, or keyword).
/// 3. **Log file** — `~/.kef-remote/logs/kef-remote.log`. Always written,
///    regardless of launch method, and each line is in the file before the
///    call returns. Agents read this file directly (`make logs-*`).
///
/// ## Filtering in Xcode
/// Use the text filter bar at the bottom of the debug console:
/// - By category: "speaker", "AppDelegate", "MediaKeyInterceptor"
/// - By level: "ERROR", "WARN", "INFO", "DEBUG"
/// - By content: any keyword in the message
///
/// ## Agent access
/// ```bash
/// make logs-recent    # last 200 lines
/// make logs-errors    # errors only (also logs-warnings, logs-debug)
/// make logs-tail      # live stream
/// ```
struct AppLogger: KEFLog {

    let category: String
    private let logger: Logger

    init(subsystem: String, category: String) {
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        LogFileWriter.app.write(.debug, category: category, message: message)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        LogFileWriter.app.write(.info, category: category, message: message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        LogFileWriter.app.write(.warning, category: category, message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        LogFileWriter.app.write(.error, category: category, message: message)
    }
}

// MARK: - The app's log file

extension LogFileWriter {
    /// The one log file for the app, shared by every `AppLogger`.
    /// Also echoes each line to stderr for Xcode's console.
    static let app = LogFileWriter(
        fileURL: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
            .appendingPathComponent("logs")
            .appendingPathComponent("kef-remote.log")
    )
}
