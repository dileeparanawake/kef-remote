import Foundation
import Testing
@testable import KEFRemoteCore

/// Live test, 5 Oct: with the speaker unplugged, a volume key waited
/// 18 seconds for a reply before the HUD said anything.
struct DeadlineTests {

    /// Stands in for a socket read: it finishes only when its reply
    /// comes, or when it is cancelled (as cancelling a socket ends a read).
    private final class HangingRead: @unchecked Sendable {
        private var continuation: CheckedContinuation<Data, Error>?
        private(set) var wasCancelled = false

        func read() async throws -> Data {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }

        func cancel() {
            wasCancelled = true
            continuation?.resume(throwing: KEFError.notConnected)
            continuation = nil
        }
    }

    @Test func aQuickReplyComesBackAsIs() async throws {
        let reply = try await withDeadline(.seconds(5), onTimeout: {}) {
            Data([0x52, 0x11, 0xFF])
        }
        #expect(reply == Data([0x52, 0x11, 0xFF]))
    }

    @Test func noReplyInTimeEndsTheReadAndThrowsATimeout() async {
        let read = HangingRead()

        await #expect(throws: KEFError.commandTimeout) {
            try await withDeadline(.milliseconds(50), onTimeout: { read.cancel() }) {
                try await read.read()
            }
        }
        #expect(read.wasCancelled)
    }

    @Test func aFailedReadKeepsItsOwnError() async {
        await #expect(throws: KEFError.connectionRefused) {
            try await withDeadline(.seconds(5), onTimeout: {}) { () -> Data in
                throw KEFError.connectionRefused
            }
        }
    }

    @Test func aQuickReplyNeverCallsOnTimeout() async throws {
        let read = HangingRead()
        _ = try await withDeadline(.seconds(5), onTimeout: { read.cancel() }) { Data() }
        #expect(!read.wasCancelled)
    }

    /// Connect, then send and read: the longest the HUD waits to say
    /// it can't reach the speaker. He asked for about 5 seconds.
    @Test func theWorstCaseWaitIsAboutFiveSeconds() {
        #expect(TCPSpeakerConnection.connectTimeout + TCPSpeakerConnection.replyTimeout <= .seconds(5))
    }
}
