import Foundation

/// A logger that core code is handed, never one it builds itself.
///
/// The app passes `AppLogger` (os.Logger, stderr and the log file).
/// Tests pass `MockKEFLog` and check what was logged.
/// The command-line tools pass a `HandlerLog` that prints.
public protocol KEFLog: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// A `KEFLog` that hands every line to a closure.
///
/// Bridges to code that still logs through a `KEFLogHandler`.
public struct HandlerLog: KEFLog, @unchecked Sendable {
    private let handler: KEFLogHandler

    public init(_ handler: @escaping KEFLogHandler) {
        self.handler = handler
    }

    public func debug(_ message: String) { handler(.debug, message) }
    public func info(_ message: String) { handler(.info, message) }
    public func warning(_ message: String) { handler(.warning, message) }
    public func error(_ message: String) { handler(.error, message) }
}
