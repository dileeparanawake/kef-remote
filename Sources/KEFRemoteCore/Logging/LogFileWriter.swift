import Foundation

/// Writes log lines to one file, and echoes each line (to stderr in the app).
///
/// Line shape: `[HH:mm:ss.SSS] [LEVEL] [category] message`.
/// The `make logs-*` filters grep for the `[LEVEL]` labels.
///
/// - Each line is in the file before `write` returns, so a `kill -9`
///   loses nothing already logged.
/// - The file starts empty on each launch (one session per file).
/// - If the folder or file can't be made, the echo says so once,
///   and lines still reach the echo.
public final class LogFileWriter: @unchecked Sendable {

    public typealias Echo = @Sendable (String) -> Void

    /// Prints a line to stderr (Xcode's debug console).
    public static let standardError: Echo = { line in fputs(line, stderr) }

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

    public init(fileURL: URL, echo: @escaping Echo = LogFileWriter.standardError) {
        self.fileURL = fileURL
        self.echo = echo
        do {
            self.fileHandle = try Self.openFresh(fileURL)
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
