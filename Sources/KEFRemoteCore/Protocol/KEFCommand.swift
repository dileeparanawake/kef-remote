import Foundation

/// Builds raw byte commands for the KEF speaker protocol.
///
/// The KEF speaker accepts commands over TCP on port 50001.
/// All commands follow a simple pattern:
///
/// - **GET** (read a value): 3 bytes — `[0x47, register, 0x80]`
/// - **SET** (write a value): 4 bytes — `[0x53, register, 0x81, value]`
///
/// The speaker responds with 4 bytes. The payload is always in byte 4 (index 3).
///
/// Only two registers are used for core speaker control:
/// - `0x25` — Volume (0–100 unmuted, 128–228 muted)
/// - `0x30` — Source byte (packed bitfield: power, inverse, standby, input)
///
/// Reference: Perl `kefctl` by Sebastian Riedel, lines 21–22.
enum KEFCommand {

    // MARK: - Register addresses

    /// Volume register. Values 0–100 (unmuted) or 128–228 (muted).
    static let volumeRegister: UInt8 = 0x25

    /// Source register. Packed bitfield — see `SourceByte`.
    static let sourceRegister: UInt8 = 0x30

    // MARK: - GET commands

    /// Read the current volume byte from the speaker.
    static func getVolume() -> Data {
        Data([0x47, volumeRegister, 0x80])
    }

    /// Read the current source byte from the speaker.
    static func getSource() -> Data {
        Data([0x47, sourceRegister, 0x80])
    }

    // MARK: - SET commands

    /// Set the volume byte on the speaker.
    static func setVolume(_ value: UInt8) -> Data {
        Data([0x53, volumeRegister, 0x81, value])
    }

    /// Set the source byte on the speaker.
    static func setSource(_ value: UInt8) -> Data {
        Data([0x53, sourceRegister, 0x81, value])
    }

    // MARK: - Response parsing

    /// Extract the payload byte from a 4-byte speaker response.
    /// Returns `nil` if the response is too short.
    static func parseResponse(_ data: Data) -> UInt8? {
        guard data.count >= 4 else { return nil }
        return data[3]
    }
}
