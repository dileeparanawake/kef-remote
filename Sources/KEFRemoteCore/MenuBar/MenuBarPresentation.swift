import Foundation

/// How a ``ConnectionStatus`` looks in the menu bar: the icon, and the
/// two lines at the top of the menu.
///
/// ```
/// Connected to LSX          Not connected
/// 192.168.1.80              Can't reach LSX at 192.168.1.80
///                           Find speaker
/// ```
///
/// The icon changes shape, not colour, so it reads in light and dark
/// menu bars and needs no colour vision.
public struct MenuBarPresentation: Equatable, Sendable {
    /// An SF Symbol name.
    public let symbolName: String
    /// True only when the speaker answered the last exchange.
    public let isConnected: Bool
    /// The menu's first line: connected or not.
    public let title: String
    /// The menu's second line: where the speaker is, or why it isn't connected.
    public let detail: String
    /// Whether the menu shows "Find speaker". Hidden while discovery
    /// already runs, and off the home network, where it can't find anything.
    public let offersFindSpeaker: Bool

    /// What VoiceOver reads for the icon.
    public var accessibilityLabel: String { "KEF Remote: \(title). \(detail)" }

    public init(status: ConnectionStatus, speakerName: String?, ip: String?) {
        let name = speakerName ?? "the speaker"
        let address = ip ?? "no IP"

        isConnected = status == .connected
        title = isConnected ? "Connected to \(name)" : "Not connected"

        switch status {
        case .dormant, .searching, .connected:
            offersFindSpeaker = false
        case .noSpeaker, .connecting, .notConnected:
            offersFindSpeaker = true
        }

        switch status {
        case .dormant:
            symbolName = "speaker.slash"
            detail = "Paused: not on home network"
        case .noSpeaker:
            symbolName = "hifispeaker.badge.plus"
            detail = "No speaker set"
        case .searching:
            symbolName = "magnifyingglass"
            detail = "Looking for the speaker…"
        case .connecting:
            symbolName = "hifispeaker"
            detail = "Checking \(name) at \(address)…"
        case .connected:
            symbolName = "hifispeaker.fill"
            detail = address
        case .notConnected:
            symbolName = "hifispeaker.badge.exclamationmark"
            detail = "Can't reach \(name) at \(address)"
        }
    }
}
