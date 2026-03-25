import Foundation
import KEFRemoteCore

/// Test factory that creates and tracks MockKefLog instances.
final class MockKefLogFactory: KefLogFactory, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockKefLogFactory")
    private var _createdLoggers: [MockKefLog] = []

    var createdLoggers: [MockKefLog] {
        queue.sync { _createdLoggers }
    }

    func makeLogger(category: String) -> KefLog {
        let logger = MockKefLog(category: category)
        queue.sync { _createdLoggers.append(logger) }
        return logger
    }
}
