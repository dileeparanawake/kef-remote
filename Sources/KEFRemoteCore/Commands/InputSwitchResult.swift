import Foundation

/// How a switch from Input ▸ went, read back from the speaker
/// (``SpeakerController/switchInput(to:)``).
public enum InputSwitchResult: Equatable, Sendable {
    /// The speaker is on this input now, as it reads it (Bluetooth may
    /// read as the unpaired code).
    case switched(InputSource)
    /// It stayed on another input: it may not have the one asked for,
    /// as an LSX has no USB.
    case notTaken(asked: InputSource, stayedOn: InputSource)
    /// It's off, so nothing was sent: it ignores input writes while off.
    case speakerOff
}
