/// Volume up, volume down or mute: from a modifier + media key, or a
/// recorded shortcut. These are the only media keys the app takes from
/// the Mac while the modifier is held; `MediaKeyInterceptor` reads the
/// key code, and this says which key it is.
///
/// Play/pause, next and previous stay the Mac's: the speaker acks its
/// playback register (0x31), but nothing plays or pauses on Wi-Fi,
/// Bluetooth or AirPlay, and KEF's own remote does the same (hand test
/// round 6).
public enum VolumeCommand: Equatable, Sendable {
    case up
    case down
    case mute

    // Key codes from IOKit's ev_keymap.h (NX_KEYTYPE_*).
    private static let soundUpKeyCode = 0
    private static let soundDownKeyCode = 1
    private static let muteKeyCode = 7

    /// The command for a system-defined event's key code, or nil for a
    /// key that stays the Mac's (brightness, play/pause and so on).
    public init?(mediaKeyCode: Int) {
        switch mediaKeyCode {
        case Self.soundUpKeyCode: self = .up
        case Self.soundDownKeyCode: self = .down
        case Self.muteKeyCode: self = .mute
        default: return nil
        }
    }
}

extension VolumeCommand: CustomStringConvertible {
    /// The name in log lines: "volume up", "mute".
    public var description: String {
        switch self {
        case .up: "volume up"
        case .down: "volume down"
        case .mute: "mute"
        }
    }
}
