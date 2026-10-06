import Foundation

/// Lets one command talk to the speaker at a time, in the order they
/// asked.
///
/// The speaker has one TCP connection and answers in order, so two
/// commands at once cross their replies. In the hand test of 6 Oct 2026
/// two quick volume presses each read 45% and wrote 50%, two more read
/// each other's reply ("Invalid response ... 52 12 FF"), and the
/// speaker's control server refused every connection until it was power
/// cycled. A command holds its turn for all its exchanges, so a read and
/// the write that follows it (volume up, a source byte change) finish
/// before the next command reads.
///
/// Locked rather than an actor so ``isBusy`` can be read at once, from
/// the menu as it opens.
public final class SpeakerExchangeQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var isRunning = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Whether a command has the speaker now (others may wait behind it).
    public var isBusy: Bool { lock.withLock { isRunning } }

    /// How many commands are waiting behind the one that has the speaker.
    public var waitingCount: Int { lock.withLock { waiting.count } }

    /// Wait for the speaker, run `body`, then hand it to the next in line.
    /// `body` must not call `run` on the same queue: it would wait for itself.
    public func run<T>(_ body: () async throws -> T) async rethrows -> T {
        await takeTurn()
        defer { handOn() }
        return try await body()
    }

    private func takeTurn() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let goesNow = lock.withLock {
                if isRunning {
                    waiting.append(continuation)
                    return false
                }
                isRunning = true
                return true
            }
            if goesNow { continuation.resume() }
        }
    }

    /// Give the turn to the first in line, or free the speaker.
    private func handOn() {
        let next: CheckedContinuation<Void, Never>? = lock.withLock {
            guard !waiting.isEmpty else {
                isRunning = false
                return nil
            }
            return waiting.removeFirst()
        }
        next?.resume()
    }
}
