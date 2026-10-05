import Foundation

/// What the menu bar icon shows about the speaker.
///
/// The TCP connection opens lazily on the first command, so there is no
/// live "connected" state. The status is the result of the last thing
/// the app tried.
public enum ConnectionStatus: String, Equatable, Sendable {
    /// Off the home network: media keys and shortcuts are off.
    case dormant
    /// No speaker IP in config.
    case noSpeaker
    /// Discovery is looking for the speaker on the network.
    case searching
    /// A speaker IP is set and no command has run yet.
    case ready
    /// The last command succeeded.
    case ok
    /// The last command failed. Reconnecting or rediscovery follows.
    case error
}

extension ConnectionStatus {
    /// The status before any command has run, or after settings change.
    ///
    /// - Parameters:
    ///   - isActive: On the home network, with media keys and shortcuts on.
    ///   - speakerIP: The IP in config, if any.
    public static func idle(isActive: Bool, speakerIP: String?) -> ConnectionStatus {
        guard isActive else { return .dormant }
        guard let speakerIP, !speakerIP.isEmpty else { return .noSpeaker }
        return .ready
    }
}
