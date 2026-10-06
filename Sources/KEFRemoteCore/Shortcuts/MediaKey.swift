/// Volume up, volume down or mute: from a modifier + media key, or a
/// recorded shortcut.
public enum VolumeCommand: Sendable {
    case up
    case down
    case mute
}

/// A media key the app takes from the Mac while the modifier is held.
/// `MediaKeyInterceptor` reads the key code; this says which key it is.
public enum MediaKey: Equatable, Sendable {
    case volume(VolumeCommand)
    case playback(PlaybackCommand)

    // Key codes from IOKit's ev_keymap.h (NX_KEYTYPE_*).
    private static let soundUp = 0
    private static let soundDown = 1
    private static let mute = 7
    private static let play = 16
    private static let next = 17
    private static let previous = 18
    private static let fast = 19
    private static let rewind = 20

    /// The key for a system-defined event's key code, or nil for a key
    /// that stays the Mac's (brightness, eject and so on).
    ///
    /// Keyboards send one pair or the other for F9 and F7: NEXT and
    /// PREVIOUS, or FAST and REWIND. Both pairs skip.
    public init?(keyCode: Int) {
        switch keyCode {
        case Self.soundUp: self = .volume(.up)
        case Self.soundDown: self = .volume(.down)
        case Self.mute: self = .volume(.mute)
        case Self.play: self = .playback(.playPause)
        case Self.next, Self.fast: self = .playback(.next)
        case Self.previous, Self.rewind: self = .playback(.previous)
        default: return nil
        }
    }
}

extension MediaKey: CustomStringConvertible {
    /// The name in log lines: "volume up", "play/pause".
    public var description: String {
        switch self {
        case .volume(.up): "volume up"
        case .volume(.down): "volume down"
        case .volume(.mute): "mute"
        case .playback(let command): command.name
        }
    }
}
