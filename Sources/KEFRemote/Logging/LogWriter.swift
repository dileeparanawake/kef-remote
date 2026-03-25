import Foundation
import os

/// Manages stderr output and log file output for the app.
///
/// The log file is truncated on each app launch (fresh log per session).
/// Writes are synchronised via a serial dispatch queue to prevent interleaving
/// from concurrent callers. DateFormatter access also happens inside the queue
/// (DateFormatter is not thread-safe).
final class LogWriter: @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.kef-remote.logwriter")
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        self.dateFormatter = dateFormatter

        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
            .appendingPathComponent("logs")

        do {
            try FileManager.default.createDirectory(
                at: logDir,
                withIntermediateDirectories: true
            )
        } catch {
            os.Logger(subsystem: "com.kef-remote", category: "LogWriter")
                .warning("Failed to create log directory: \(error.localizedDescription, privacy: .public)")
            self.fileHandle = nil
            return
        }

        let logPath = logDir.appendingPathComponent("kef-remote.log")

        // Truncate on launch (fresh log each session).
        FileManager.default.createFile(atPath: logPath.path, contents: nil)
        let handle = FileHandle(forWritingAtPath: logPath.path)

        if handle == nil {
            os.Logger(subsystem: "com.kef-remote", category: "LogWriter")
                .warning("Failed to open log file for writing - file output unavailable")
            fputs("[LogWriter] WARNING: Log file unavailable - stderr only\n", stderr)
        }

        self.fileHandle = handle
    }

    deinit {
        try? fileHandle?.close()
    }

    /// Formats and writes a log entry to stderr and log file.
    ///
    /// stderr is always written first, unconditionally. The file write
    /// is synchronous on the serial queue. If the file handle is nil,
    /// stderr still works.
    func write(level: String, category: String, message: String) {
        let line = queue.sync {
            let timestamp = dateFormatter.string(from: Date())
            return "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
        }

        // stderr - always visible, unconditional.
        fputs(line, stderr)

        // Log file - synchronous write, independent of stderr.
        if let fileHandle, let data = line.data(using: .utf8) {
            queue.sync { fileHandle.write(data) }
        }
    }
}
