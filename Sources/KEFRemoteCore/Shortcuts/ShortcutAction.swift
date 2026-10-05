/// What a global keyboard shortcut does. Each one has a recorder in
/// Settings, and the app turns a press into a speaker command.
///
/// Volume up, volume down and mute also work as modifier + media key;
/// these shortcuts are an extra way in, unset until the user records one.
public enum ShortcutAction: CaseIterable, Sendable {
    case powerToggle
    case volumeUp
    case volumeDown
    case mute
    case quit

    /// The key the shortcut is saved under (`KeyboardShortcuts_<name>`
    /// in UserDefaults). Never rename one: the user's recording is lost.
    public var storageName: String {
        switch self {
        case .powerToggle: "powerToggle"
        case .volumeUp: "volumeUp"
        case .volumeDown: "volumeDown"
        case .mute: "mute"
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
        case .quit: "Quit"
        }
    }
}
