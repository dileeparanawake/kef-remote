import Foundation

/// How a ``ConnectionStatus`` looks in the menu bar: the icon and the
/// status line at the top of the menu.
///
/// The icon changes shape, not colour, so it reads in light and dark
/// menu bars and needs no colour vision.
public struct MenuBarPresentation: Equatable, Sendable {
    /// An SF Symbol name.
    public let symbolName: String
    /// The status line shown at the top of the menu.
    public let title: String

    /// What VoiceOver reads for the icon.
    public var accessibilityLabel: String { "KEF Remote: \(title)" }

    public init(status: ConnectionStatus, speakerName: String?, ip: String?) {
        let name = speakerName ?? "the speaker"
        switch status {
        case .dormant:
            symbolName = "speaker.slash"
            title = "Paused: not on home network"
        case .noSpeaker:
            symbolName = "hifispeaker.badge.plus"
            title = "No speaker set"
        case .searching:
            symbolName = "magnifyingglass"
            title = "Looking for the speaker…"
        case .ready:
            symbolName = "hifispeaker"
            title = "\(speakerName ?? "Speaker") at \(ip ?? "no IP")"
        case .ok:
            symbolName = "hifispeaker.fill"
            title = "Connected to \(name)"
        case .error:
            symbolName = "exclamationmark.triangle"
            title = "Can't reach \(name)"
        }
    }
}
