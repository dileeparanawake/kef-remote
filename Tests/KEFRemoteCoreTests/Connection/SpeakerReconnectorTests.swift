import Foundation
import Testing
@testable import KEFRemoteCore

/// After a failed command: drop the connection once, wait, reconnect
/// once. In the hand test of 6 Oct 2026 (18:36:38-41) each failed press
/// started its own reconnect, two connected at once, and the speaker's
/// control server refused every connection until it was power cycled.
struct SpeakerReconnectorTests {
    /// Runs a scheduled reconnect only when the test says so.
    final class Harness {
        let clock = SimulatedClock()
        let log = MockKEFLog()
        var scheduled: [(wait: Duration, run: @Sendable () -> Void)] = []
        var drops = 0
        var reconnects: [Bool] = []
        lazy var reconnector: SpeakerReconnector = {
            let reconnector = SpeakerReconnector(clock: clock, log: log.handler) { [unowned self] wait, run in
                scheduled.append((wait, run))
            }
            reconnector.dropConnection = { [unowned self] in drops += 1 }
            reconnector.reconnect = { [unowned self] rediscover in reconnects.append(rediscover) }
            return reconnector
        }()

        /// Let the clock reach the first scheduled reconnect, and run it.
        func waitAndRunReconnect() async {
            let next = scheduled.removeFirst()
            await clock.sleep(for: next.wait)
            next.run()
        }
    }

    /// v0.2.0's promise, which 0.3.0 lost: after an error, presses are
    /// ignored for about two seconds while it reconnects, once.
    @Test func afterAnErrorNothingReachesTheSpeakerForTwoSecondsThenOneReconnect() async {
        let harness = Harness()
        harness.reconnector.commandFailed(KEFError.invalidResponse, searchesBySelf: true)

        #expect(harness.drops == 1)
        #expect(harness.reconnects.isEmpty)
        #expect(harness.scheduled.map(\.wait) == [.seconds(2)])
        #expect(harness.reconnector.isWaiting)

        await harness.waitAndRunReconnect()
        #expect(harness.reconnects == [false])
        #expect(!harness.reconnector.isWaiting)
    }

    @Test func errorsWhileItWaitsStartNoSecondReconnect() async {
        let harness = Harness()
        harness.reconnector.commandFailed(KEFError.invalidResponse, searchesBySelf: true)
        harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: true)
        harness.reconnector.commandFailed(KEFError.notConnected, searchesBySelf: true)

        #expect(harness.drops == 1)
        #expect(harness.scheduled.count == 1)
        #expect(harness.log.messages(at: .info).contains {
            $0.hasPrefix("Command failed (connectionRefused) while a reconnect waits (in 2 s): not starting another")
        })
    }

    /// Each failed reconnect in a row waits longer, so a struggling
    /// speaker isn't asked again and again.
    @Test func itBacksOffTwoFourEightThenTen() async {
        let harness = Harness()
        var waits: [Duration] = []
        for _ in 0..<5 {
            harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: false)
            waits.append(harness.scheduled.last!.wait)
            await harness.waitAndRunReconnect()
        }
        #expect(waits == [.seconds(2), .seconds(4), .seconds(8), .seconds(10), .seconds(10)])
        #expect(harness.reconnects.count == 5)
    }

    @Test func anAnswerStartsTheBackOffAgain() async {
        let harness = Harness()
        harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: false)
        await harness.waitAndRunReconnect()
        harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: false)
        await harness.waitAndRunReconnect()

        harness.reconnector.speakerAnswered()
        harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: false)
        #expect(harness.scheduled.last?.wait == .seconds(2))
    }

    /// A speaker that can't be reached may have a new IP: in Auto it is
    /// looked for after the wait, not straight away.
    @Test func anUnreachableSpeakerIsLookedForAfterTheWait() async {
        let harness = Harness()
        harness.reconnector.commandFailed(KEFError.connectionRefused, searchesBySelf: true)
        #expect(harness.reconnects.isEmpty)
        await harness.waitAndRunReconnect()
        #expect(harness.reconnects == [true])
        #expect(harness.log.messages(at: .info).contains(
            "Command failed (connectionRefused): dropping the connection; looking for the speaker in 2 s"
        ))
    }

    /// A reply out of step means the connection is out of step, not that
    /// the speaker moved: reconnect to the same IP.
    @Test func aBadReplyReconnectsToTheSameIP() async {
        let harness = Harness()
        harness.reconnector.commandFailed(KEFError.invalidResponse, searchesBySelf: true)
        await harness.waitAndRunReconnect()
        #expect(harness.reconnects == [false])
        #expect(harness.log.messages(at: .info).contains(
            "Command failed (invalidResponse): dropping the connection; reconnecting in 2 s"
        ))
    }

    @Test func itSaysHowLongIsLeft() async {
        let harness = Harness()
        #expect(harness.reconnector.waitLeft == nil)
        harness.reconnector.commandFailed(KEFError.invalidResponse, searchesBySelf: false)
        await harness.clock.sleep(for: .milliseconds(500))
        #expect(harness.reconnector.waitLeft == .milliseconds(1500))
    }
}
