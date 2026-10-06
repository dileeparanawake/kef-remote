import Foundation

/// How a play/pause, next or previous press went
/// (``SpeakerController/sendPlayback(_:)``).
public enum PlaybackResult: Equatable, Sendable {
    /// Sent, and the speaker acked it.
    case sent
    /// Not sent: the speaker is on this input, which it doesn't stream
    /// itself (``InputSource/hasPlayback``).
    case notOnThisInput(InputSource)
    /// Not sent: the speaker is off.
    case speakerOff
}
