import Foundation

/// Turns the global shortcuts off while any of the app's menus is open,
/// and back on when it closes.
///
/// While a menu tracks, AppKit holds the keyboard; KeyboardShortcuts says
/// to disable its shortcuts then (its `NSMenuItem.setShortcut` docs), or
/// events buffer and fire again. Its menu mode fired one key-up 176 times
/// in the 6 Oct hand test. ``ShortcutRepeatFilter`` and
/// ``PowerToggleGuard`` stay as the safety net.
///
/// ```
/// menu begins ─┬─ shortcuts on (home network) ─ disable all, remember it
///              └─ already off (dormant) ─────── leave them off
/// menu ends ───┬─ this turned them off ──────── enable all
///              └─ otherwise ─────────────────── leave them
/// ```
///
/// Only the names it disabled are enabled again; going dormant is a
/// separate switch (KeyboardShortcuts' `isEnabled`), so a menu closing
/// off the home network doesn't turn the shortcuts back on.
public struct MenuTrackingShortcuts: Equatable, Sendable {
    /// What to do to the shortcuts.
    public enum Change: Equatable, Sendable {
        case disable
        case enable
        /// The shortcuts are off already (off the home network): a menu
        /// opening leaves them off.
        case leaveOff
        /// Nothing to do, and nothing worth a log line.
        case leave

        /// One line under `shortcuts`, or nil for ``leave``.
        public var logLine: String? {
            switch self {
            case .disable: "shortcuts paused: a menu is open"
            case .enable: "shortcuts back on: the menu closed"
            case .leaveOff: "menu opened: shortcuts already off (off the home network)"
            case .leave: nil
            }
        }
    }

    /// This turned the shortcuts off for an open menu, and owes an enable.
    public private(set) var disabledForMenu = false

    public init() {}

    /// A menu began tracking.
    /// - Parameter shortcutsOn: The shortcuts are on now (home network).
    public mutating func menuBegan(shortcutsOn: Bool) -> Change {
        guard !disabledForMenu else { return .leave }
        guard shortcutsOn else { return .leaveOff }
        disabledForMenu = true
        return .disable
    }

    /// A menu ended tracking.
    public mutating func menuEnded() -> Change {
        guard disabledForMenu else { return .leave }
        disabledForMenu = false
        return .enable
    }

    /// A quiet, greyed-out line in the menu bar menu, so he knows a
    /// shortcut pressed now does nothing (hand test round 6). Only on the
    /// home network: off it (``ConnectionStatus/dormant``) the shortcuts
    /// are off anyway, and the menu's first lines say why.
    public static func menuLine(status: ConnectionStatus) -> String? {
        status == .dormant ? nil : "Shortcuts paused while this menu is open"
    }
}
