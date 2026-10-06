/// Which of the app's own windows (setup, settings) are open, and so
/// whether KEF Remote shows a Dock icon.
///
/// KEF Remote has no Dock icon. But a window opened from the menu bar
/// can end up behind another app's, and without a Dock icon it is in
/// neither the Dock nor Cmd-Tab, so it seems to vanish (hand test round
/// 3). While any of its windows is open the app shows a Dock icon, like
/// any app with a window, and hides it when the last one closes.
///
/// ```
/// opened setup     -> show        closed settings -> (setup still open)
/// opened settings  -> (no change) closed setup    -> hide
/// ```
public struct OpenWindows: Sendable {
    /// What to do with the Dock icon after a window opens or closes.
    public enum DockIconChange: Equatable, Sendable {
        case show
        case hide
    }

    private var open: Set<String> = []

    public init() {}

    public var needsDockIcon: Bool { !open.isEmpty }

    /// - Parameter name: Names the window, e.g. "setup".
    /// - Returns: `.show` for the first window open, else nil.
    public mutating func opened(_ name: String) -> DockIconChange? {
        let hadNone = open.isEmpty
        open.insert(name)
        return hadNone ? .show : nil
    }

    /// - Returns: `.hide` once the last window closes, else nil. Hiding
    ///   it sooner would make the app give up the front, and drop the
    ///   window still open behind other apps' windows.
    public mutating func closed(_ name: String) -> DockIconChange? {
        guard open.remove(name) != nil else { return nil }
        return open.isEmpty ? .hide : nil
    }
}
