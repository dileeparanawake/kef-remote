import Foundation
import os
import KEFRemoteCore

/// Triple-output logger conforming to the KefLog protocol.
///
/// Every log message is written to three destinations simultaneously:
/// 1. **os.Logger** - Apple's unified logging system (all content `.public`)
/// 2. **stderr** - visible in Xcode console, filterable by category/level/keyword
/// 3. **Log file** - `~/.kef-remote/logs/kef-remote.log` (truncated each launch)
///
/// Logging never throws - each destination is independent. If the log file
/// can't be written, os.Logger and stderr still receive the message.
struct AppLogger: KefLog, @unchecked Sendable {

    let category: String
    private let osLogger: os.Logger
    private let writer: LogWriter

    init(subsystem: String, category: String, writer: LogWriter) {
        self.category = category
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
        self.writer = writer
    }

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        writer.write(level: "DEBUG", category: category, message: message)
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        writer.write(level: "INFO", category: category, message: message)
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        writer.write(level: "WARN", category: category, message: message)
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        writer.write(level: "ERROR", category: category, message: message)
    }
}
