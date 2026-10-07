import Foundation

/// Lets one power toggle reach the speaker at a time, and none straight
/// after another.
///
/// In the hand test of 6 Oct 2026 one press fired the power shortcut 176
/// times together (see ``ShortcutRepeatFilter``). Each fire read the
/// speaker and wrote power off, and its control server stopped answering
/// until it was restarted. Whatever sends the toggles, this keeps a burst
/// from reaching the speaker.
///
/// The rule: a toggle is refused while another is in flight, and for
/// ``minimumGap`` after the last one finished.
public struct PowerToggleGuard: Equatable, Sendable {
    /// Power on takes seconds on the LSX (5 s in the real check), so a
    /// second toggle sooner than this is a repeat, not a choice.
    public static let minimumGap: Duration = .seconds(1)

    /// Why a toggle was refused.
    public enum Refusal: Equatable, Sendable {
        case inFlight
        case tooSoon(sinceLast: Duration)

        /// The reason, for the log line.
        public var reason: String {
            switch self {
            case .inFlight:
                "another power change is still going"
            case .tooSoon(let sinceLast):
                "\(Self.milliseconds(sinceLast)) ms after the last one "
                    + "(needs \(Self.milliseconds(PowerToggleGuard.minimumGap)) ms)"
            }
        }

        private static func milliseconds(_ duration: Duration) -> Int {
            Int((duration / .milliseconds(1)).rounded())
        }
    }

    private var isInFlight = false
    private var lastFinishedAt: Duration?

    public init() {}

    /// Start a toggle at `now`, or say why not. A refusal changes nothing.
    public mutating func start(at now: Duration) -> Refusal? {
        if isInFlight { return .inFlight }
        if let lastFinishedAt, now - lastFinishedAt < Self.minimumGap {
            return .tooSoon(sinceLast: now - lastFinishedAt)
        }
        isInFlight = true
        return nil
    }

    /// The toggle started last has finished, whether or not it worked.
    public mutating func finish(at now: Duration) {
        isInFlight = false
        lastFinishedAt = now
    }
}

/// How a power toggle went (``SpeakerController/togglePower(applying:)``).
public enum PowerToggleResult: Equatable, Sendable {
    case turnedOn
    case turnedOff
    /// Nothing sent: too close to another toggle (``PowerToggleGuard``).
    case ignored(PowerToggleGuard.Refusal)
}
