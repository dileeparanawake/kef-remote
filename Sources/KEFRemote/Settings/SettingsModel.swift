import KEFRemoteCore
import KeyboardShortcuts
import SwiftUI

/// What the settings window can ask the app to do. `AppDelegate` fills
/// these in, so each change applies straight away, with no restart.
struct SettingsActions {
    /// Save a new speaker IP and connect to it.
    var saveSpeakerIP: (String) -> Void
    /// Look for the speaker on the network, and save it if found.
    var discoverSpeaker: () async -> DiscoveryOutcome
    /// Use a new modifier key for the media keys.
    var applyModifier: (MediaKeyModifier) -> Void
    /// Find the speaker by itself (Auto) or only use the typed IP (Manual).
    var applyDiscovery: (DiscoveryMode) -> Void
    /// Save the input the speaker switches to when the app turns it on.
    var applyPowerOnInput: (PowerOnInput) -> Void
}

/// State for the settings window: the discovery mode, the IP field,
/// discovery, the power-on input, the media key modifier, and refusing a
/// shortcut that is already taken. Shortcuts are stored by the
/// KeyboardShortcuts recorders themselves; the model checks and logs each
/// change.
///
/// Every action is logged under the `settings` category.
@MainActor
final class SettingsModel: ObservableObject {
    /// What is in the IP field. Saved on Return or Save.
    @Published var ipText: String
    /// The IP in config.
    @Published private(set) var savedIP: String?
    /// One line under the speaker section: the last save or discovery result.
    @Published private(set) var note: String?
    @Published private(set) var isDiscovering = false
    @Published private(set) var modifier: MediaKeyModifier
    @Published private(set) var discovery: DiscoveryMode
    @Published private(set) var powerOnInput: PowerOnInput

    private let actions: SettingsActions
    private let log = AppLogger(subsystem: "com.kef-remote", category: "settings")

    init(savedIP: String?, discovery: DiscoveryMode, speakerSettings: SpeakerSettings, actions: SettingsActions) {
        self.savedIP = savedIP
        self.ipText = savedIP ?? ""
        self.discovery = discovery
        self.powerOnInput = speakerSettings.powerOnInput
        self.modifier = MediaKeyModifier.stored
        self.actions = actions
    }

    /// True when the field holds a valid IP that is not saved yet.
    var canSaveIP: Bool {
        guard let ip = SpeakerIP.parse(ipText) else { return false }
        return ip != savedIP
    }

    func saveIP() {
        guard let ip = SpeakerIP.parse(ipText) else {
            log.info("IP not saved: \"\(ipText)\" is not an IPv4 address")
            note = "That is not an IP address, like 192.168.1.80"
            return
        }
        guard ip != savedIP else { return }
        log.info("IP saved: \(savedIP ?? "none") -> \(ip)")
        ipText = ip
        savedIP = ip
        note = "Saved"
        actions.saveSpeakerIP(ip)
    }

    func discover() async {
        log.info("Discover clicked")
        isDiscovering = true
        note = "Looking for the speaker…"
        let outcome = await actions.discoverSpeaker()
        isDiscovering = false
        note = outcome.message
        log.info("Discover result: \(outcome.message)")
    }

    func setDiscovery(_ mode: DiscoveryMode) {
        guard mode != discovery else { return }
        log.info("discovery \(discovery.rawValue) -> \(mode.rawValue)")
        discovery = mode
        note = nil
        actions.applyDiscovery(mode)
    }

    func setPowerOnInput(_ choice: PowerOnInput) {
        guard choice != powerOnInput else { return }
        log.info("power-on input \(powerOnInput.rawValue) -> \(choice.rawValue)")
        powerOnInput = choice
        actions.applyPowerOnInput(choice)
    }

    func setModifier(_ choice: MediaKeyModifier) {
        guard choice != modifier else { return }
        log.info("modifier \(modifier.rawValue) -> \(choice.rawValue)")
        modifier = choice
        MediaKeyModifier.store(choice)
        actions.applyModifier(choice)
    }

    /// Refuse a combo another action already uses, so one press never
    /// does two things. The recorder shows the reason and keeps the old one.
    func validateShortcut(_ shortcut: KeyboardShortcuts.Shortcut, for action: ShortcutAction) -> KeyboardShortcuts.ValidationResult {
        guard let other = action.conflict(with: shortcut, in: { KeyboardShortcuts.getShortcut(for: $0.name) }) else {
            return .allow
        }
        log.info("shortcut refused: \(action.label) = \(shortcut), already used for \(other.label)")
        return .disallow(reason: other.alreadyUsedMessage)
    }

    /// A recorder saved a new shortcut (nil: cleared). KeyboardShortcuts
    /// has already stored it and swapped the hot key, so it works now.
    func shortcutRecorded(_ action: ShortcutAction, as shortcut: KeyboardShortcuts.Shortcut?) {
        log.info("shortcut recorded: \(action.label) = \(shortcut.map { "\($0)" } ?? "cleared")")
    }

    /// Show an IP the app saved itself (after discovery). Leaves the
    /// field alone if the user is part-way through typing in it.
    func showSavedIP(_ ip: String?) {
        let fieldWasClean = ipText == (savedIP ?? "")
        savedIP = ip
        if fieldWasClean { ipText = ip ?? "" }
    }
}
