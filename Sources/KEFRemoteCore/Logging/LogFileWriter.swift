import Foundation

/// Writes log lines to one file, and echoes each line (to stderr in the app).
///
/// Line shape: `[HH:mm:ss.SSS] [LEVEL] [category] message`.
/// The `make logs-*` filters grep for the `[LEVEL]` labels.
///
/// - Each line is in the file before `write` returns, so a `kill -9`
///   loses nothing already logged.
/// - The app's file starts empty on each launch (one session per file).
///   `kef-check` appends instead, so a check run sits after the app's
///   last session rather than wiping it.
/// - If the folder or file can't be made, the echo says so once,
///   and lines still reach the echo.
public final class LogFileWriter: @unchecked Sendable {

    public typealias Echo = @Sendable (String) -> Void

    /// Prints a line to stderr (Xcode's debug console).
    public static let standardError: Echo = { line in fputs(line, stderr) }

    /// The one log file: `~/.kef-remote/logs/kef-remote.log`. The app
    /// and `kef-check` both write here, and `make logs-*` read it.
    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
            .appendingPathComponent("logs")
            .appendingPathComponent("kef-remote.log")
    }

    public let fileURL: URL

    /// Whether lines reach the file. False when it couldn't be opened.
    public var isWritingToFile: Bool { fileHandle != nil }

    private let echo: Echo
    private let fileHandle: FileHandle?
    /// Serialises writes so lines never interleave. `DateFormatter`
    /// isn't thread-safe, so it's only used on this queue too.
    private let queue = DispatchQueue(label: "com.kef-remote.log-file-writer")
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// - Parameter appending: Keep the lines already in the file and
    ///   write after them, rather than starting it empty.
    public init(fileURL: URL, echo: @escaping Echo = LogFileWriter.standardError, appending: Bool = false) {
        self.fileURL = fileURL
        self.echo = echo
        do {
            self.fileHandle = try appending ? Self.openForAppending(fileURL) : Self.openFresh(fileURL)
        } catch {
            self.fileHandle = nil
            write(.warning, category: "LogFileWriter",
                  message: "Log file unavailable at \(fileURL.path) (\(error.localizedDescription)) — lines go to stderr only")
        }
    }

    deinit {
        try? fileHandle?.close()
    }

    public func write(_ level: KEFLogLevel, category: String, message: String) {
        queue.sync {
            let timestamp = timestampFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(level.label)] [\(category)] \(message)\n"
            echo(line)
            fileHandle?.write(Data(line.utf8))
        }
    }

    /// Makes the folder, empties the file, and opens it for writing.
    private static func openFresh(_ url: URL) throws -> FileHandle {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: url)
        return try FileHandle(forWritingTo: url)
    }

    /// Makes the folder and file if missing, and opens the file so every
    /// write lands at its end (O_APPEND), even if another writer added lines.
    private static func openForAppending(_ url: URL) throws -> FileHandle {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let descriptor = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }
}

extension KEFLogLevel {
    /// The tag written into each log line.
    public var label: String {
        switch self {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warning: "WARN"
        case .error: "ERROR"
        }
    }
}
