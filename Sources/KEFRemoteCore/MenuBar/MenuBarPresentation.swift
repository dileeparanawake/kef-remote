import Foundation

/// How a ``ConnectionStatus`` looks in the menu bar: the icon, its dot,
/// and the two lines at the top of the menu.
///
/// ```
/// icon, no dot              icon with a red dot
/// Connected to LSX           Can't reach LSX: click Find speaker
/// 192.168.1.80               No answer at 192.168.1.80
///                            Find speaker
/// ```
///
/// The red dot marks a state that needs him. It is a shape as well as a
/// colour, so it reads without colour vision. A state with a dot puts
/// what's wrong and what to do on the menu's first line. A green dot
/// shows briefly on connecting (see ``ConnectedFlash``), and an orange
/// one pulses while it looks for the speaker (see ``SearchingPulse``).
public struct MenuBarPresentation: Equatable, Sendable {
    /// An SF Symbol name.
    public let symbolName: String
    /// Show a red dot on the icon: something needs him.
    public let needsAttention: Bool
    /// The dot to draw: red when it needs him, orange while it looks for
    /// the speaker, green while it has just connected, else none. Red
    /// always wins.
    public let dot: MenuBarDot
    /// True only when the speaker answered the last exchange.
    public let isConnected: Bool
    /// The menu's first line: connected, or what's wrong and what to do.
    public let title: String
    /// The menu's second line: where the speaker is, or more on what's wrong.
    public let detail: String
    /// Whether the menu shows "Find speaker". Hidden while discovery
    /// already runs, and off the home network, where it can't find anything.
    public let offersFindSpeaker: Bool

    /// What VoiceOver reads for the icon.
    public var accessibilityLabel: String { "KEF Remote: \(title). \(detail)" }

    /// The outline speaker: while checking, and under the red and orange
    /// dots. Plain, because the dot sits where a badge would be.
    static let plainSpeakerSymbol = "hifispeaker"
    static let notConnectedTitle = "Not connected"

    /// - Parameter isFlashingConnected: Within ``ConnectedFlash/duration``
    ///   of becoming connected.
    public init(status: ConnectionStatus, speakerName: String?, ip: String?, isFlashingConnected: Bool = false) {
        let name = speakerName ?? "the speaker"
        let address = ip ?? "no IP"

        isConnected = status == .connected

        switch status {
        case .dormant, .searching, .connected:
            offersFindSpeaker = false
        case .noSpeaker, .connecting, .notConnected, .localNetworkBlocked:
            offersFindSpeaker = true
        }

        switch status {
        case .connected, .connecting, .searching, .dormant:
            needsAttention = false
        case .noSpeaker, .notConnected, .localNetworkBlocked:
            needsAttention = true
        }

        if needsAttention {
            dot = .needsAttention
        } else if status == .searching {
            dot = .searching
        } else if isConnected && isFlashingConnected {
            dot = .justConnected
        } else {
            dot = .none
        }

        switch status {
        case .dormant:
            symbolName = "speaker.slash"
            title = Self.notConnectedTitle
            detail = "Paused: not on home network"
        case .searching:
            // The speaker stays (Round 3, 5 Oct): the pulsing dot says
            // it's looking, so the icon doesn't jump to a new shape.
            symbolName = Self.plainSpeakerSymbol
            title = Self.notConnectedTitle
            detail = "Looking for the speaker…"
        case .connecting:
            symbolName = Self.plainSpeakerSymbol
            title = Self.notConnectedTitle
            detail = "Checking \(name) at \(address)…"
        case .connected:
            symbolName = "hifispeaker.fill"
            title = "Connected to \(name)"
            detail = address
        case .noSpeaker:
            symbolName = Self.plainSpeakerSymbol
            title = "No speaker set: click Find speaker"
            detail = "Or type its IP in Settings…"
        case .notConnected:
            symbolName = Self.plainSpeakerSymbol
            title = "Can't reach \(name): click Find speaker"
            detail = "No answer at \(address)"
        case .localNetworkBlocked:
            symbolName = Self.plainSpeakerSymbol
            title = "Can't reach \(name): allow Local Network in System Settings"
            detail = "Privacy & Security > Local Network > KEF Remote"
        }
    }
}
