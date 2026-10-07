import Foundation

/// Time for waiting on the speaker: how long since the clock was made,
/// and a way to wait. The app and the real check wait for real; the dry
/// run and the tests share a ``SimulatedClock`` with the
/// ``SimulatedSpeaker``, so a 20-second wait for power takes no time.
public protocol SpeakerClock: AnyObject {
    /// Time since the clock was made.
    var now: Duration { get }
    func sleep(for duration: Duration) async
}

/// Wall-clock time, for the real speaker.
public final class RealSpeakerClock: SpeakerClock {
    private let start = ContinuousClock.now

    public init() {}

    public var now: Duration { ContinuousClock.now - start }

    public func sleep(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

/// Time that moves only when something sleeps, and at once.
///
/// Locked: in the burst tests many tasks read it while the simulated
/// speaker moves it on for each reply.
public final class SimulatedClock: SpeakerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var elapsed: Duration = .zero

    public init() {}

    public var now: Duration { lock.withLock { elapsed } }

    public func sleep(for duration: Duration) async {
        lock.withLock { elapsed += duration }
    }
}
