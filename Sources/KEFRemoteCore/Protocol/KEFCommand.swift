import Foundation

/// Builds raw byte commands for the KEF speaker protocol.
///
/// The KEF speaker accepts commands over TCP on port 50001.
/// All commands follow a simple pattern:
///
/// - **GET** (read a value): 3 bytes — `[0x47, register, 0x80]`
/// - **SET** (write a value): 4 bytes — `[0x53, register, 0x81, value]`
///
/// Responses differ by command type:
/// - **GET response:** 5 bytes — `[0x52, register, 0x81, value, checksum]`.
///   The payload is in byte 4 (index 3).
/// - **SET response:** 3 bytes — always `[0x52, 0x11, 0xFF]` (acknowledgement).
///
/// Only two registers are used for core speaker control:
/// - `0x25` — Volume (0–100 unmuted, 128–228 muted)
/// - `0x30` — Source byte (packed bitfield: power, inverse, standby, input)
///
/// Reference: Perl `kefctl` by Sebastian Riedel, lines 21–22.
enum KEFCommand {

    // MARK: - Response sizes

    /// A GET response from the speaker is 5 bytes.
    static let getResponseSize = 5

    /// A SET acknowledgement from the speaker is 3 bytes.
    static let setResponseSize = 3

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

    /// Extract the payload byte from a 5-byte GET response.
    /// Returns `nil` if the response is not a full GET response (e.g. a 3-byte SET ack).
    static func parseResponse(_ data: Data) -> UInt8? {
        guard data.count >= 5 else { return nil }
        return data[3]
    }

    /// Check whether the response is a SET acknowledgement (`52 11 FF`).
    static func isSetAck(_ data: Data) -> Bool {
        data == Data([0x52, 0x11, 0xFF])
    }

    // MARK: - Response validation

    /// Validate the header of a 5-byte GET response.
    ///
    /// Expected shape: `[0x52, register, 0x81, value, checksum]`
    /// - `data[0]` must be `0x52`
    /// - `data[1]` must match the queried `register`
    /// - `data[2]` must be `0x81`
    ///
    /// Throws `KEFError.invalidResponse` if any check fails.
    static func validateGetResponse(_ data: Data, register: UInt8) throws {
        guard data.count == getResponseSize else { throw KEFError.invalidResponse }
        guard data[0] == 0x52, data[1] == register, data[2] == 0x81 else {
            throw KEFError.invalidResponse
        }
    }

    /// Validate a 3-byte SET acknowledgement.
    ///
    /// Must be exactly `[0x52, 0x11, 0xFF]`.
    /// Throws `KEFError.invalidResponse` if the ack is malformed.
    static func validateSetResponse(_ data: Data) throws {
        guard isSetAck(data) else { throw KEFError.invalidResponse }
    }
}
