import Foundation

/// A pretend KEF speaker that answers the protocol from memory: reads
/// return what it holds, writes change it.
///
/// `kef-check --dry-run` runs against it, so the check's output can be
/// seen without touching the real speaker (it changes what's playing).
/// The tests use it as a speaker that remembers what it was sent.
///
/// It copies the two habits of the real speaker the check depends on:
/// - Bluetooth reads back as the unpaired code (1111) while nothing is
///   paired, whichever code selected it.
/// - A source write with the power bit off and 20-minute standby crashes
///   the speaker's control server, and it stops answering.
public final class SimulatedSpeaker: SpeakerConnection {
    private var volumeByte: UInt8
    private var sourceByte: UInt8
    private let hasPairedBluetooth: Bool

    /// True once it was sent the write that crashes a real speaker.
    public private(set) var hasCrashed = false

    /// What it holds now.
    public var volume: VolumeState { VolumeCoding.decode(volumeByte) }
    public var source: SourceByte { SourceByte(byte: sourceByte) }

    public init(volume: VolumeState, source: SourceByte, hasPairedBluetooth: Bool = false) {
        self.volumeByte = VolumeCoding.encode(level: volume.level, isMuted: volume.isMuted)
        self.sourceByte = source.encode()
        self.hasPairedBluetooth = hasPairedBluetooth
    }

    public func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        guard !hasCrashed else {
            throw KEFError.connectionFailed("simulated speaker crashed (power off with 20 min standby)")
        }
        let bytes = [UInt8](data)
        if bytes == [UInt8](KEFCommand.getVolume()) {
            return reply(register: KEFCommand.volumeRegister, value: volumeByte)
        }
        if bytes == [UInt8](KEFCommand.getSource()) {
            return reply(register: KEFCommand.sourceRegister, value: sourceByte)
        }
        if bytes.count == 4, data == KEFCommand.setVolume(bytes[3]) {
            volumeByte = bytes[3]
            return Self.ack
        }
        if bytes.count == 4, data == KEFCommand.setSource(bytes[3]) {
            try write(source: SourceByte(byte: bytes[3]))
            return Self.ack
        }
        throw KEFError.invalidResponse
    }

    private func write(source: SourceByte) throws {
        if !source.isPoweredOn && source.standby == .twentyMinutes {
            hasCrashed = true
            throw KEFError.connectionFailed("simulated speaker crashed (power off with 20 min standby)")
        }
        var kept = source
        if source.input.isSameInput(as: .bluetoothPaired) {
            kept = source.with(input: hasPairedBluetooth ? .bluetoothPaired : .bluetoothUnpaired)
        }
        sourceByte = kept.encode()
    }

    /// A GET reply: `52 <register> 81 <value> <checksum>`. The checksum
    /// is left at 0: the controller never reads it.
    private func reply(register: UInt8, value: UInt8) -> Data {
        Data([0x52, register, 0x81, value, 0x00])
    }

    /// The speaker's acknowledgement of a write.
    private static let ack = Data([0x52, 0x11, 0xFF])
}
