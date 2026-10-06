import Foundation

/// Time for the speaker check: how long since it started, and a way to
/// wait. The real run waits for real; the dry run and the tests share a
/// ``SimulatedClock`` with the ``SimulatedSpeaker``, so a 20-second wait
/// for power takes no time at all.
public protocol CheckClock: AnyObject {
    /// Time since the clock was made.
    var now: Duration { get }
    func sleep(for duration: Duration) async
}

/// Wall-clock time, for the real speaker.
public final class RealCheckClock: CheckClock {
    private let start = ContinuousClock.now

    public init() {}

    public var now: Duration { ContinuousClock.now - start }

    public func sleep(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

/// Time that moves only when something sleeps, and at once.
public final class SimulatedClock: CheckClock {
    public private(set) var now: Duration = .zero

    public init() {}

    public func sleep(for duration: Duration) async {
        now += duration
    }
}
