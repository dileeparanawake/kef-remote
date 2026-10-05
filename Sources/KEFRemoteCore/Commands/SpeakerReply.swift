import Foundation

/// Whether the speaker answered an exchange. ``SpeakerController`` reports
/// one after every send, so the app always knows if it is connected.
public enum SpeakerReply: Equatable, Sendable {
    /// The speaker sent bytes back.
    case answered
    /// The speaker could not be reached. Carries the reason, for the log.
    case unreachable(String)
    /// macOS kept the app off the local network. Carries the reason, for the log.
    case localNetworkBlocked(String)
}
