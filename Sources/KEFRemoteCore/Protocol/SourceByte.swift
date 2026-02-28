import Foundation

/// Input source for the KEF speaker.
///
/// Each source has a unique 4-bit value stored in bits 3-0 of the source byte.
/// Reference: Perl `kefctl` lines 88-93, 173-180.
public enum InputSource: UInt8, CaseIterable, Codable {
    case wifi             = 0b0010
    case usb              = 0b1100
    case bluetoothPaired  = 0b1001
    case bluetoothUnpaired = 0b1111
    case aux              = 0b1010
    case optical          = 0b1011
}

/// Standby timeout mode for the KEF speaker.
///
/// Stored in bits 5-4 of the source byte.
/// **Warning:** 20-minute standby causes the speaker's control server to crash
/// on power-off. The app only exposes 60-minute and never to the user.
/// 20-minute is used internally by dynamic standby management.
///
/// Reference: Perl `kefctl` lines 80-85, 167-171.
public enum StandbyMode: UInt8, CaseIterable, Codable {
    case twentyMinutes = 0b00
    case sixtyMinutes  = 0b01
    case never         = 0b10
}

/// Decodes and encodes the KEF source byte (register 0x30).
///
/// The source byte is a **packed bitfield** that stores four independent
/// settings in a single byte:
///
/// ```
/// Bit:  7       6         5-4        3-0
///       Power   Inverse   Standby    Input source
///       0=on    0=off     00=20min   0010=WiFi
///       1=off   1=on      01=60min   1100=USB
///                         10=never   1001=Bluetooth
///                                    1010=Aux
///                                    1011=Optical
/// ```
///
/// **Critical:** Every SET operation must use read-modify-write. Read the
/// current byte, change only the bits you need, write it back. Otherwise
/// you'll clobber the other settings (e.g., setting input could turn off power).
///
/// Reference: Perl `kefctl` lines 68-98, 150-186, 217-234.
public struct SourceByte: Equatable {
    public var isPoweredOn: Bool
    public var isInversed: Bool
    public var standby: StandbyMode
    public var input: InputSource

    /// Decode a raw source byte into its component fields.
    public init(byte: UInt8) {
        // Bit 7: Power (0 = on, 1 = off) — note the inversion
        isPoweredOn = (byte >> 7) & 1 == 0
        // Bit 6: Inverse L/R
        isInversed = (byte >> 6) & 1 == 1
        // Bits 5-4: Standby mode
        standby = StandbyMode(rawValue: (byte >> 4) & 0b11) ?? .sixtyMinutes
        // Bits 3-0: Input source
        input = InputSource(rawValue: byte & 0b1111) ?? .optical
    }

    /// Create a source byte with explicit values (for building new commands).
    public init(isPoweredOn: Bool, isInversed: Bool, standby: StandbyMode, input: InputSource) {
        self.isPoweredOn = isPoweredOn
        self.isInversed = isInversed
        self.standby = standby
        self.input = input
    }

    /// Encode this source byte back into a raw byte for sending to the speaker.
    public func encode() -> UInt8 {
        var byte: UInt8 = 0
        // Bit 7: Power (0 = on, 1 = off)
        if !isPoweredOn { byte |= (1 << 7) }
        // Bit 6: Inverse L/R
        if isInversed { byte |= (1 << 6) }
        // Bits 5-4: Standby
        byte |= (standby.rawValue << 4)
        // Bits 3-0: Input source
        byte |= input.rawValue
        return byte
    }

    // MARK: - Read-modify-write helpers

    /// Return a copy with only the power state changed. All other fields preserved.
    public func with(isPoweredOn: Bool) -> SourceByte {
        var copy = self
        copy.isPoweredOn = isPoweredOn
        return copy
    }

    /// Return a copy with only the input changed. All other fields preserved.
    public func with(input: InputSource) -> SourceByte {
        var copy = self
        copy.input = input
        return copy
    }

    /// Return a copy with only the standby mode changed. All other fields preserved.
    public func with(standby: StandbyMode) -> SourceByte {
        var copy = self
        copy.standby = standby
        return copy
    }
}
