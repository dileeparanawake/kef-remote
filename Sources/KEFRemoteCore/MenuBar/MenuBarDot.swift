import Foundation

/// The dot on the menu bar icon, bottom-right.
public enum MenuBarDot: Equatable, Sendable {
    case none
    /// Red: something needs him (see ``MenuBarPresentation/needsAttention``).
    case needsAttention
    /// Green, for ``ConnectedFlash/duration``: it just connected, so he
    /// sees something happened.
    case justConnected
}

/// The brief green dot when the app connects to, or finds, the speaker.
///
/// ```
/// connecting ──answered──> connected ●green ──2 s──> connected (no dot)
/// ```
public enum ConnectedFlash {
    /// Long enough to notice, short enough not to linger.
    public static let duration: Duration = .seconds(2)

    /// Whether a status change starts the flash: only a change into
    /// connected, never a repeat of it.
    public static func starts(from old: ConnectionStatus, to new: ConnectionStatus) -> Bool {
        new == .connected && old != .connected
    }
}
