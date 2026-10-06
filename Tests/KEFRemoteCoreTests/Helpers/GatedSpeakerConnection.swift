import Foundation
@testable import KEFRemoteCore

/// A connection whose sends wait until ``open()``, so a test can start a
/// command and act while it is in flight. Safe to call from many tasks at
/// once, as the app does when presses come in together.
final class GatedSpeakerConnection: SpeakerConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Data]
    private var sent: [Data] = []
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(responses: [Data]) {
        self.responses = responses
    }

    /// Every command sent so far, in order.
    var sentCommands: [Data] { lock.withLock { sent } }

    /// Let every waiting send, and every later one, through.
    func open() {
        let toResume = lock.withLock {
            isOpen = true
            defer { waiting = [] }
            return waiting
        }
        toResume.forEach { $0.resume() }
    }

    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        lock.withLock { sent.append(data) }
        await withCheckedContinuation { continuation in
            let goesNow = lock.withLock {
                if isOpen { return true }
                waiting.append(continuation)
                return false
            }
            if goesNow { continuation.resume() }
        }
        return try lock.withLock {
            guard !responses.isEmpty else { throw KEFError.invalidResponse }
            return responses.removeFirst()
        }
    }
}
