import Foundation
import KEFRemoteCore

/// Test double that captures log entries for assertion.
final class MockKefLog: KefLog, @unchecked Sendable {
    let category: String

    struct Entry: Equatable {
        let level: LogLevel
        let message: String
    }

    private let queue = DispatchQueue(label: "MockKefLog")
    private var _entries: [Entry] = []

    var entries: [Entry] {
        queue.sync { _entries }
    }

    init(category: String) {
        self.category = category
    }

    func debug(_ message: String) {
        queue.sync { _entries.append(Entry(level: .debug, message: message)) }
    }

    func info(_ message: String) {
        queue.sync { _entries.append(Entry(level: .info, message: message)) }
    }

    func warning(_ message: String) {
        queue.sync { _entries.append(Entry(level: .warning, message: message)) }
    }

    func error(_ message: String) {
        queue.sync { _entries.append(Entry(level: .error, message: message)) }
    }
}
