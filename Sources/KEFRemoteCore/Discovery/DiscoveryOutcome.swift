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

extension DiscoveryOutcome {
    /// A failed search, with a hint when the cause is likely a setting.
    ///
    /// macOS answers "No route to host" when the app is not allowed on
    /// the local network, so name that permission.
    public static func failure(_ error: Error) -> DiscoveryOutcome {
        var reason = "\(error)"
        if let socketError = error as? SocketError, socketError.code == EHOSTUNREACH {
            reason += ". Allow KEF Remote in System Settings > Privacy & Security > Local Network."
        }
        return .failed(reason)
    }
}
