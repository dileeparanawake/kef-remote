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
public final class SimulatedClock: SpeakerClock {
    public private(set) var now: Duration = .zero

    public init() {}

    public func sleep(for duration: Duration) async {
        now += duration
    }
}
