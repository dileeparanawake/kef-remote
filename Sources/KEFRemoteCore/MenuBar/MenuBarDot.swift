import Foundation

/// The dot on the menu bar icon, bottom-right.
public enum MenuBarDot: Equatable, Sendable {
    case none
    /// Red: something needs him (see ``MenuBarPresentation/needsAttention``).
    case needsAttention
    /// Green, for ``ConnectedFlash/duration``: it just connected, so he
    /// sees something happened.
    case justConnected
    /// Orange, pulsing (``SearchingPulse``): it's looking for the speaker.
    case searching

    /// Whether the dot fades in and out. Only the orange one does, so a
    /// steady dot always means a settled state.
    public var pulses: Bool { self == .searching }
}

/// The brief green dot when the app connects to, or finds, the speaker.
///
/// ```
/// connecting ──answered──> connected ●green ──4 s──> connected (no dot)
/// ```
public enum ConnectedFlash {
    /// Long enough to notice: 2 s went before he looked (Round 3, 5 Oct).
    public static let duration: Duration = .seconds(4)

    /// Whether a status change starts the flash: only a change into
    /// connected, never a repeat of it.
    public static func starts(from old: ConnectionStatus, to new: ConnectionStatus) -> Bool {
        new == .connected && old != .connected
    }
}

/// How the orange dot fades while it looks for the speaker.
///
/// ```
/// opacity
/// 1.0  ●╮       ╭●╮       ╭●
///       ╰╮     ╭╯ ╰╮     ╭╯
/// 0.35   ╰──●──╯   ╰──●──╯
///      0   0.5 s  1 s
/// ```
///
/// It starts full, so the dot is seen the moment finding starts, and
/// never fades out, so it's always there to see.
public enum SearchingPulse {
    /// One fade out and back in. Slow enough to read as calm, not alarm.
    public static let period: Duration = .seconds(1)
    public static let brightestOpacity = 1.0
    public static let dimmestOpacity = 0.35
    /// How often the icon is redrawn while it pulses: 20 frames a
    /// period looks smooth at menu bar size and costs little.
    public static let frameInterval: Duration = .milliseconds(50)

    /// The dot's opacity this long after the pulse started: a cosine
    /// from brightest down to dimmest and back, once per ``period``.
    public static func opacity(after elapsed: Duration) -> Double {
        let phase = elapsed / period
        let towardsBright = (1 + cos(2 * .pi * phase)) / 2
        return dimmestOpacity + (brightestOpacity - dimmestOpacity) * towardsBright
    }
}
