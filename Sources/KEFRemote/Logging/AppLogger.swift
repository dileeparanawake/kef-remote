import Foundation
import os

/// Triple-output logger for KEF Remote.
///
/// Every log message is written to three destinations simultaneously:
/// 1. **os.Logger** — Apple's unified logging system. Works with `log stream`
///    and `log show` when the app runs standalone (outside Xcode).
/// 2. **stderr** — Always appears in Xcode's debug console. Filter using
///    the text filter bar (type a category, level, or keyword).
/// 3. **Log file** — `~/.kef-remote/logs/kef-remote.log`. Always written,
///    regardless of launch method. Agents read this file directly.
///
/// ## Filtering in Xcode
/// Use the text filter bar at the bottom of the debug console:
/// - By category: "speaker", "AppDelegate", "MediaKeyInterceptor"
/// - By level: "ERROR", "WARN", "INFO", "DEBUG"
/// - By content: any keyword in the message
///
/// ## Agent access
/// ```bash
/// cat ~/.kef-remote/logs/kef-remote.log     # full log
/// tail -50 ~/.kef-remote/logs/kef-remote.log # last 50 lines
/// tail -f ~/.kef-remote/logs/kef-remote.log  # live stream
/// ```
struct AppLogger {

    let category: String
    private let logger: Logger

    init(subsystem: String, category: String) {
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        LogFile.shared.write(level: "DEBUG", category: category, message: message)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        LogFile.shared.write(level: "INFO", category: category, message: message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        LogFile.shared.write(level: "WARN", category: category, message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        LogFile.shared.write(level: "ERROR", category: category, message: message)
    }
}

// MARK: - Log file + stderr writer

/// Manages the shared log file and stderr output.
///
/// The log file is truncated on first access each app launch, ensuring
/// a fresh log for each session. Writes are synchronised via a serial
/// dispatch queue to avoid interleaving from concurrent callers.
final class LogFile {

    static let shared = LogFile()

    private let queue = DispatchQueue(label: "com.kef-remote.logfile")
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
            .appendingPathComponent("logs")

        try? FileManager.default.createDirectory(
            at: logDir,
            withIntermediateDirectories: true
        )

        let logPath = logDir.appendingPathComponent("kef-remote.log")

        // Truncate on launch (fresh log each session).
        FileManager.default.createFile(atPath: logPath.path, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: logPath.path)
        fileHandle?.seekToEndOfFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    func write(level: String, category: String, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"

        // stderr — always visible in Xcode console.
        fputs(line, stderr)

        // Log file — always written for agent access.
        if let data = line.data(using: .utf8) {
            queue.async { [weak self] in
                self?.fileHandle?.write(data)
            }
        }
    }
}
