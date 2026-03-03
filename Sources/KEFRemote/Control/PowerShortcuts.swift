import KeyboardShortcuts

// MARK: - Shortcut name definitions

extension KeyboardShortcuts.Name {
    /// Power on the speaker. Default: Cmd+Shift+O.
    static let powerOn = Self("powerOn", default: .init(.o, modifiers: [.command, .shift]))

    /// Power off the speaker. Default: Cmd+Shift+P.
    static let powerOff = Self("powerOff", default: .init(.p, modifiers: [.command, .shift]))

    /// Quit the app. Default: Cmd+Shift+Q.
    static let quit = Self("quit", default: .init(.q, modifiers: [.command, .shift]))
}

// MARK: - PowerShortcuts

/// Manages power and quit keyboard shortcuts using the KeyboardShortcuts library.
///
/// Default shortcuts:
/// - Power On: Cmd+Shift+O
/// - Power Off: Cmd+Shift+P
/// - Quit: Cmd+Shift+Q
///
/// Shortcuts are user-configurable via the settings window (Task 21)
/// using `KeyboardShortcuts.RecorderCocoa` views. The actual speaker
/// commands are NOT wired up here -- that happens in the integration
/// task (Task 22). This class only provides the shortcut registration
/// and callback mechanism.
///
/// Usage:
/// ```swift
/// let shortcuts = PowerShortcuts()
/// shortcuts.onPowerOn = { print("Power on") }
/// shortcuts.onPowerOff = { print("Power off") }
/// shortcuts.onQuit = { NSApp.terminate(nil) }
/// shortcuts.register()
/// ```
final class PowerShortcuts {

    // MARK: - Callbacks

    /// Called when the power-on shortcut is triggered.
    var onPowerOn: (() -> Void)?

    /// Called when the power-off shortcut is triggered.
    var onPowerOff: (() -> Void)?

    /// Called when the quit shortcut is triggered.
    var onQuit: (() -> Void)?

    // MARK: - Lifecycle

    /// Register all keyboard shortcut listeners.
    ///
    /// Each shortcut fires its corresponding callback on key-up.
    /// Call this once after setting the callback properties.
    func register() {
        KeyboardShortcuts.onKeyUp(for: .powerOn) { [weak self] in
            self?.onPowerOn?()
        }
        KeyboardShortcuts.onKeyUp(for: .powerOff) { [weak self] in
            self?.onPowerOff?()
        }
        KeyboardShortcuts.onKeyUp(for: .quit) { [weak self] in
            self?.onQuit?()
        }
    }

    /// Unregister all keyboard shortcut listeners.
    ///
    /// Disables the event monitors for each shortcut. The shortcut
    /// definitions (names and defaults) remain available for the
    /// settings UI.
    func unregister() {
        KeyboardShortcuts.disable(.powerOn)
        KeyboardShortcuts.disable(.powerOff)
        KeyboardShortcuts.disable(.quit)
    }

    deinit {
        unregister()
    }
}
