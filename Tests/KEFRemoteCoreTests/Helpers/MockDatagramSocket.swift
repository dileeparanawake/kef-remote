import Foundation
@testable import KEFRemoteCore

/// Test double for DatagramSocket. Queue up replies, inspect what was sent.
final class MockDatagramSocket: DatagramSocket, @unchecked Sendable {
    struct Sent: Equatable {
        let data: Data
        let host: String
        let port: UInt16
    }

    private let lock = NSLock()
    private var queued: [Datagram]
    private var sentLog: [Sent] = []
    private var closed = false

    /// If set, `send` throws this.
    var sendError: Error?

    init(replies: [Datagram] = []) {
        self.queued = replies
    }

    var sent: [Sent] { lock.lock(); defer { lock.unlock() }; return sentLog }
    var isClosed: Bool { lock.lock(); defer { lock.unlock() }; return closed }

    func send(_ data: Data, toHost host: String, port: UInt16) throws {
        if let sendError { throw sendError }
        lock.lock(); defer { lock.unlock() }
        sentLog.append(Sent(data: data, host: host, port: port))
    }

    /// Returns the next queued reply at once, or nil (as if the deadline passed).
    func receive(until deadline: ContinuousClock.Instant) async throws -> Datagram? {
        lock.lock(); defer { lock.unlock() }
        return queued.isEmpty ? nil : queued.removeFirst()
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        closed = true
    }
}
