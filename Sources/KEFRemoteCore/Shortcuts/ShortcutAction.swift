/// What a global keyboard shortcut does. Each one has a recorder in
/// Settings, and the app turns a press into a speaker command.
///
/// Volume up, volume down, mute, play/pause, next and previous also work
/// as modifier + media key; these shortcuts are an extra way in, unset
/// until the user records one.
public enum ShortcutAction: CaseIterable, Sendable {
    case powerToggle
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case nextTrack
    case previousTrack
    case quit

    /// The key the shortcut is saved under (`KeyboardShortcuts_<name>`
    /// in UserDefaults). Never rename one: the user's recording is lost.
    public var storageName: String {
        switch self {
        case .powerToggle: "powerToggle"
        case .volumeUp: "volumeUp"
        case .volumeDown: "volumeDown"
        case .mute: "mute"
        case .playPause: "playPause"
        case .nextTrack: "nextTrack"
        case .previousTrack: "previousTrack"
        case .quit: "quit"
        }
    }

    /// The label beside its recorder in Settings, and in log lines.
    public var label: String {
        switch self {
        case .powerToggle: "Power on/off"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .mute: "Mute"
        case .playPause: "Play/pause"
        case .nextTrack: "Next"
        case .previousTrack: "Previous"
        case .quit: "Quit"
        }
    }
}

extension ShortcutAction {
    /// The other action already using `shortcut`, if any, so one press
    /// never does two things.
    ///
    /// - Parameter savedShortcut: Each action's saved shortcut, or nil.
    public func conflict<Shortcut: Equatable>(
        with shortcut: Shortcut,
        in savedShortcut: (ShortcutAction) -> Shortcut?
    ) -> ShortcutAction? {
        Self.allCases.first { $0 != self && savedShortcut($0) == shortcut }
    }

    /// Why a recording was refused, when this action already has the combo.
    public var alreadyUsedMessage: String { "Already used for \(label)" }
}
