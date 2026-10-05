import Foundation

/// What a discovery run ended with, and the line settings shows for it.
public enum DiscoveryOutcome: Equatable, Sendable {
    /// Found and saved.
    case found(AppConfig.SpeakerConfig)
    /// The search ran, but no matching KEF answered.
    case notFound
    /// The search could not run (socket or send error).
    case failed(String)
    /// A search was already running, so this one did not start.
    case alreadyRunning

    /// One short line for the settings window.
    public var message: String {
        switch self {
        case .found(let speaker):
            return "Found \(speaker.name ?? "the speaker") at \(speaker.lastKnownIp ?? "no IP")"
        case .notFound:
            return "No KEF speaker answered"
        case .failed(let reason):
            return "Discovery failed: \(reason)"
        case .alreadyRunning:
            return "Already looking"
        }
    }
}
