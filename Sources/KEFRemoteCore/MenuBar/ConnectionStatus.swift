import Foundation

/// Whether the app is connected to the speaker, and if not, why.
///
/// The TCP connection opens lazily, so "connected" means the speaker
/// answered the last exchange: a command, or the check the app runs
/// whenever it sets up a speaker connection.
public enum ConnectionStatus: String, Equatable, Sendable {
    /// Off the home network: media keys and shortcuts are off.
    case dormant
    /// No speaker IP in config.
    case noSpeaker
    /// Discovery is looking for the speaker on the network.
    case searching
    /// A speaker IP is set and the app is checking that it answers.
    case connecting
    /// The speaker answered the last exchange.
    case connected
    /// The speaker could not be reached on the last exchange.
    case notConnected
}

extension ConnectionStatus {
    /// The status before the speaker has been asked anything, or after
    /// settings change.
    ///
    /// - Parameters:
    ///   - isActive: On the home network, with media keys and shortcuts on.
    ///   - speakerIP: The IP in config, if any.
    public static func idle(isActive: Bool, speakerIP: String?) -> ConnectionStatus {
        guard isActive else { return .dormant }
        guard let speakerIP, !speakerIP.isEmpty else { return .noSpeaker }
        return .connecting
    }

    /// The status after the speaker answered, or didn't.
    public init(_ reply: SpeakerReply) {
        switch reply {
        case .answered: self = .connected
        case .unreachable: self = .notConnected
        }
    }
}
