import Foundation

/// Recovers from a failed command: drops the connection once, waits,
/// then reconnects once, and waits longer each time that fails.
///
/// In the hand test of 6 Oct 2026 (18:36:38-41) each failed press started
/// its own reconnect: two connected at once, every press tried again, and
/// the speaker's control server refused every connection until it was
/// power cycled. v0.2.0 promised "after an error, presses are ignored for
/// about two seconds while it reconnects"; this keeps that promise and
/// backs off from there.
///
/// The rule:
/// - The first failure drops the connection and schedules one reconnect
///   after ``wait(afterFailures:)``. Commands meanwhile have no connection,
///   so they are skipped (the app logs one line each).
/// - Failures while a reconnect waits change nothing (one log line).
/// - Each failure that follows a reconnect, with no answer between, waits
///   twice as long: 2, 4, 8, then 10 s. An answer starts again at 2 s.
/// - A speaker that couldn't be reached may have a new IP, so in Auto it
///   is looked for after the wait. A bad reply (out of step) reconnects to
///   the same IP.
///
/// Call it from one thread (the app's main thread); that is why it can
/// be marked Sendable, for the closure it schedules.
public final class SpeakerReconnector: @unchecked Sendable {
    /// v0.2.0's wait: long enough for the speaker to let go of the old
    /// connection (it takes one at a time and refuses a new one for a
    /// moment), short enough that the next press works.
    public static let firstWait: Duration = .seconds(2)
    /// The longest wait: a speaker coming back is found within this.
    public static let longestWait: Duration = .seconds(10)

    /// Run the closure after the wait (the app: on the main queue).
    public typealias Schedule = (_ wait: Duration, _ run: @escaping @Sendable () -> Void) -> Void

    /// Drops the connection, so nothing reaches the speaker until the reconnect.
    public var dropConnection: () -> Void = {}
    /// Reconnects: by looking for the speaker if `true`, else to the saved IP.
    public var reconnect: (_ lookForSpeaker: Bool) -> Void = { _ in }

    private let clock: SpeakerClock
    private let log: KEFLogHandler
    private let schedule: Schedule
    private var failuresInARow = 0
    private var reconnectAt: Duration?

    public init(clock: SpeakerClock, log: @escaping KEFLogHandler, schedule: @escaping Schedule) {
        self.clock = clock
        self.log = log
        self.schedule = schedule
    }

    /// Whether a reconnect is waiting to start.
    public var isWaiting: Bool { reconnectAt != nil }

    /// How long until the waiting reconnect starts; nil if none waits.
    public var waitLeft: Duration? { reconnectAt.map { max($0 - clock.now, .zero) } }

    /// How long to wait after `failures` failures in a row (0 for the first).
    public static func wait(afterFailures failures: Int) -> Duration {
        // Doubling from 2 s passes 10 s at the fourth; stop counting there.
        let doublings = min(failures, 3)
        return min(firstWait * (1 << doublings), longestWait)
    }

    /// A command failed with `error`. Drops the connection and schedules
    /// one reconnect, unless one is already waiting.
    ///
    /// - Parameter searchesBySelf: Discovery is Auto, so an unreachable
    ///   speaker is looked for rather than reconnected at its saved IP.
    public func commandFailed(_ error: Error, searchesBySelf: Bool) {
        if let waitLeft {
            log(.info, "Command failed (\(error)) while a reconnect waits (in \(Self.seconds(waitLeft))): not starting another")
            return
        }
        let lookForSpeaker = ((error as? KEFError)?.isConnectionFailure ?? false) && searchesBySelf
        let wait = Self.wait(afterFailures: failuresInARow)
        failuresInARow += 1
        reconnectAt = clock.now + wait
        dropConnection()
        let next = lookForSpeaker ? "looking for the speaker" : "reconnecting"
        log(.info, "Command failed (\(error)): dropping the connection; \(next) in \(Self.seconds(wait))")
        schedule(wait) { [weak self] in
            guard let self else { return }
            self.reconnectAt = nil
            self.log(.info, "Waited \(Self.seconds(wait)) after the failure: \(next) now")
            self.reconnect(lookForSpeaker)
        }
    }

    /// The speaker answered: the next failure waits the shortest time again.
    public func speakerAnswered() {
        guard failuresInARow > 0 else { return }
        failuresInARow = 0
        log(.info, "Speaker answered: the next reconnect waits \(Self.seconds(Self.firstWait)) again")
    }

    /// A wait for the log: "2 s", or "1.5 s".
    public static func seconds(_ duration: Duration) -> String {
        let seconds = duration / .seconds(1)
        if seconds == seconds.rounded() { return "\(Int(seconds)) s" }
        return String(format: "%.1f s", seconds)
    }
}
