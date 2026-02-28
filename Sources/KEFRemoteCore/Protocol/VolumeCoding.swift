import Foundation

/// The volume state decoded from or to be encoded into a KEF volume byte.
public struct VolumeState: Equatable {
    /// Volume percentage, 0-100.
    public let level: Int
    /// Whether the speaker is muted.
    public let isMuted: Bool

    public init(level: Int, isMuted: Bool) {
        self.level = level
        self.isMuted = isMuted
    }
}

/// Encodes and decodes the KEF volume byte (register 0x25).
///
/// The volume byte uses a simple scheme:
/// - **0-100:** Unmuted volume level (0% to 100%)
/// - **128-228:** Muted volume level (actual volume = byte - 128)
///
/// A byte value >= 128 means the speaker is muted. The actual volume
/// is the byte minus 128. This means you can mute/unmute without
/// changing the volume level -- just add or subtract 128.
///
/// **Bug in Perl reference:** The `raise` command uses `> 128` instead
/// of `>= 128`, which mishandles the edge case of volume 0 + muted
/// (byte = 128). We use `>= 128` consistently.
///
/// Reference: Perl `kefctl` lines 109-142, 209-215.
public enum VolumeCoding {

    /// Decode a raw volume byte into a level and mute state.
    public static func decode(_ byte: UInt8) -> VolumeState {
        if byte >= 128 {
            return VolumeState(level: Int(byte) - 128, isMuted: true)
        }
        return VolumeState(level: Int(byte), isMuted: false)
    }

    /// Encode a volume level and mute state into a raw byte.
    /// Level is clamped to 0-100.
    public static func encode(level: Int, isMuted: Bool) -> UInt8 {
        let clamped = min(max(level, 0), 100)
        let base = UInt8(clamped)
        return isMuted ? base + 128 : base
    }
}
