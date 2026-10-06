import KEFRemoteCore
import KeyboardShortcuts

// MARK: - Shortcut names

extension KeyboardShortcuts.Name {
    /// Turn the speaker on if it's off, off if it's on. Initial: Cmd+Shift+O.
    static let powerToggle = Self(ShortcutAction.powerToggle.storageName, initial: .init(.o, modifiers: [.command, .shift]))

    /// Unset until recorded: modifier + media keys already do these.
    static let volumeUp = Self(ShortcutAction.volumeUp.storageName)
    static let volumeDown = Self(ShortcutAction.volumeDown.storageName)
    static let mute = Self(ShortcutAction.mute.storageName)
    static let playPause = Self(ShortcutAction.playPause.storageName)
    static let nextTrack = Self(ShortcutAction.nextTrack.storageName)
    static let previousTrack = Self(ShortcutAction.previousTrack.storageName)

    /// Quit the app. Initial: Cmd+Shift+Q.
    static let quit = Self(ShortcutAction.quit.storageName, initial: .init(.q, modifiers: [.command, .shift]))
}

extension ShortcutAction {
    /// The KeyboardShortcuts name its recorder saves to and its listener
    /// reads from. One name per action, so the two can't drift apart.
    var name: KeyboardShortcuts.Name {
        switch self {
        case .powerToggle: .powerToggle
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case .mute: .mute
        case .playPause: .playPause
        case .nextTrack: .nextTrack
        case .previousTrack: .previousTrack
        case .quit: .quit
        }
    }

    /// The saved shortcut as symbols, like "⇧⌘O", or "not set".
    @MainActor
    var shortcutText: String {
        KeyboardShortcuts.getShortcut(for: name).map { "\($0)" } ?? "not set"
    }

    /// The saved shortcut in words, like "Cmd+Shift+O", or nil if cleared.
    @MainActor
    var shortcutWords: String? {
        KeyboardShortcuts.getShortcut(for: name).map { ShortcutWords.words(fromSymbols: "\($0)") }
    }
}

// MARK: - GlobalShortcuts

/// Listens for every ``ShortcutAction``'s global shortcut and fires
/// ``onAction``. `AppDelegate` turns the action into a speaker command.
///
/// Listeners are added once, at launch: KeyboardShortcuts keeps every
/// listener it is given, so adding them on each activation would fire
/// a press twice (a power toggle would turn the speaker on, then off).
/// Going dormant and back only switches them all off and on.
///
/// A shortcut recorded in Settings applies straight away: the library
/// swaps the hot key, and the listener looks the name up on each press.
///
/// Logged under `shortcuts`:
/// ```
/// shortcut listening: Power on/off = ⇧⌘O
/// shortcut fired: Power on/off (⇧⌘O)
/// shortcuts on (on home network)
/// ```
@MainActor
final class GlobalShortcuts {

    /// Called on the main actor when a shortcut is pressed.
    var onAction: ((ShortcutAction) -> Void)?

    private var isListening = false
    private let log = AppLogger(subsystem: "com.kef-remote", category: "shortcuts")

    /// Add a listener for every action. Call once, after setting ``onAction``.
    func listen() {
        guard !isListening else { return }
        isListening = true
        for action in ShortcutAction.allCases {
            KeyboardShortcuts.onKeyUp(for: action.name) { [weak self] in
                self?.fire(action)
            }
            log.info("shortcut listening: \(action.label) = \(action.shortcutText)")
        }
    }

    /// Switch every shortcut on or off, for example off the home network.
    func setEnabled(_ isEnabled: Bool, reason: String) {
        KeyboardShortcuts.isEnabled = isEnabled
        log.info("shortcuts \(isEnabled ? "on" : "off") (\(reason))")
    }

    private func fire(_ action: ShortcutAction) {
        log.info("shortcut fired: \(action.label) (\(action.shortcutText))")
        onAction?(action)
    }
}
