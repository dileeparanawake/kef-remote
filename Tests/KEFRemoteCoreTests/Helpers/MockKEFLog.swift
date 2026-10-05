import Foundation
import KEFRemoteCore

/// Test double for KEFLog. Records every line so tests can check what was logged.
final class MockKEFLog: KEFLog, @unchecked Sendable {
    struct Entry: Equatable {
        let level: KEFLogLevel
        let message: String
    }

    private let lock = NSLock()
    private var recorded: [Entry] = []

    var entries: [Entry] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    /// Messages at one level, in order.
    func messages(at level: KEFLogLevel) -> [String] {
        entries.filter { $0.level == level }.map(\.message)
    }

    /// The same log as a closure, for code that takes a `KEFLogHandler`.
    var handler: KEFLogHandler {
        { [self] level, message in record(level, message) }
    }

    func debug(_ message: String) { record(.debug, message) }
    func info(_ message: String) { record(.info, message) }
    func warning(_ message: String) { record(.warning, message) }
    func error(_ message: String) { record(.error, message) }

    private func record(_ level: KEFLogLevel, _ message: String) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(Entry(level: level, message: message))
    }
}
