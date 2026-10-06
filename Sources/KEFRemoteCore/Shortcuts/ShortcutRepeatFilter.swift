import Foundation

/// One shortcut press, one action.
///
/// In the hand test of 6 Oct 2026 one Cmd+Shift+O press fired the power
/// shortcut 176 times in 18 ms, and the speaker's control server stopped
/// answering. The cause is in KeyboardShortcuts 3.1.0: while one of the
/// app's menus is open (the menu bar menu, or a picker in Settings) it
/// stops the system hot keys and reads key events from the app's queue
/// instead. Its run-loop monitor handles a key-up but leaves it queued,
/// so the same key-up fires the listener again on every run-loop turn
/// until the menu takes it. A headless repro fired one posted key-up
/// thousands of times in 0.3 s; with that monitor off, once.
///
/// The rule: a fire of the same action within ``samePressWithin`` of the
/// last one seen is a repeat of that press, and is dropped. The window
/// runs from the last fire seen, so a burst that keeps going stays
/// dropped.
public struct ShortcutRepeatFilter: Sendable {
    /// Burst fires come tens of microseconds apart; a person tapping a key
    /// again as fast as they can takes well over this.
    public static let samePressWithin: Duration = .milliseconds(100)

    public enum Verdict: Equatable, Sendable {
        /// A new press: run the action. `repeatsDroppedBefore` counts the
        /// repeats of the press before it, for the log.
        case fire(repeatsDroppedBefore: Int)
        /// The `count`th repeat of the last press: drop it.
        case repeatOfLastPress(count: Int)
    }

    private var lastSeenAt: [ShortcutAction: Duration] = [:]
    private var repeatsOfLastPress: [ShortcutAction: Int] = [:]

    public init() {}

    /// Whether a fire of `action` at `now` is a new press or a repeat.
    public mutating func verdict(for action: ShortcutAction, at now: Duration) -> Verdict {
        defer { lastSeenAt[action] = now }
        let repeats = repeatsOfLastPress[action, default: 0]
        if let last = lastSeenAt[action], now - last < Self.samePressWithin {
            repeatsOfLastPress[action] = repeats + 1
            return .repeatOfLastPress(count: repeats + 1)
        }
        repeatsOfLastPress[action] = 0
        return .fire(repeatsDroppedBefore: repeats)
    }
}
