import Foundation

/// What started a discovery run: a click, or the app by itself. It names
/// the run in the log, and decides whether a miss searches again
/// (``SearchAgain``).
public enum DiscoveryTrigger: Equatable, Sendable, CustomStringConvertible {
    // Clicks.
    case findSpeakerInMenu
    case findSpeakerInSetup
    case discoverInSettings
    // The app by itself.
    case localNetworkAllowed
    case noIPSaved
    case speakerUnreachable
    case switchedToAuto

    /// Someone clicked and is waiting for the answer.
    public var isClick: Bool {
        switch self {
        case .findSpeakerInMenu, .findSpeakerInSetup, .discoverInSettings: return true
        case .localNetworkAllowed, .noIPSaved, .speakerUnreachable, .switchedToAuto: return false
        }
    }

    /// The words in the log.
    public var description: String {
        switch self {
        case .findSpeakerInMenu: return "Find speaker in menu"
        case .findSpeakerInSetup: return "Find speaker in setup"
        case .discoverInSettings: return "Discover in settings"
        case .localNetworkAllowed: return "Local Network allowed"
        case .noIPSaved: return "no IP saved"
        case .speakerUnreachable: return "speaker unreachable"
        case .switchedToAuto: return "switched to Auto discovery"
        }
    }
}
