import Foundation

/// A pretend KEF speaker that answers the protocol from memory: reads
/// return what it holds, writes change it.
///
/// `kef-check --dry-run` runs against it, so the check's output can be
/// seen without touching the real speaker (it changes what's playing).
/// The tests use it as a speaker that remembers what it was sent.
///
/// It copies the habits of the real speaker the check depends on:
/// - Bluetooth reads back as the unpaired code (1111) while nothing is
///   paired, whichever code selected it.
/// - A source write with the power bit off and 20-minute standby crashes
///   the speaker's control server, and it stops answering.
/// - While it is off, it ignores input, standby and left/right writes;
///   volume and mute still take. (First real check, 6 Oct 2026: every
///   such write to a speaker that was off read back unchanged.)
/// - Turning on or off takes `powerChangeTime`. Until then it still
///   reads the old state and ignores every source write.
/// - A power change sent within `ignoresPowerChangesFor` of the last one
///   landing is ignored: "cycling it quickly looks like failure because
///   requests aren't taken" (Dileepa).
/// - For `mutedAsItComesOnFor` after power comes on, the volume reads
///   muted though it isn't. A volume written in that moment is kept as
///   written. (Second real check, 6 Oct 2026: the LSX read 45% muted
///   right as it came on; kefctl polling every second saw 45% unmuted.)
/// - With no USB input (the LSX), a switch to USB keeps the input it is
///   on. (Same check: asked for USB, it stayed on Aux.)
public final class SimulatedSpeaker: SpeakerConnection {
    private var volumeByte: UInt8
    private var sourceByte: UInt8
    private let hasPairedBluetooth: Bool
    private let keepsInputOnPowerOn: Bool
    private let hasUSBInput: Bool
    private let clock: SpeakerClock
    private let powerChangeTime: Duration
    private let ignoresPowerChangesFor: Duration
    private let mutedAsItComesOnFor: Duration

    /// A power change on its way: the byte it lands on, and when.
    private var powerChange: (source: SourceByte, landsAt: Duration)?
    /// When the last power change landed.
    private var lastPowerChangeLanded: Duration?
    /// When it last came on, for the moment it reads muted.
    private var cameOnAt: Duration?

    /// True once it was sent the write that crashes a real speaker.
    public private(set) var hasCrashed = false

    /// What it holds now.
    public var volume: VolumeState { VolumeCoding.decode(volumeByte) }
    public var source: SourceByte {
        landPowerChange()
        return SourceByte(byte: sourceByte)
    }

    /// - Parameters:
    ///   - keepsInputOnPowerOn: Power on, but ignore the input in the
    ///     same write (to test the check's report of it).
    ///   - clock: Its time. Share it with the check so waits line up.
    ///   - powerChangeTime: How long turning on or off takes.
    ///   - ignoresPowerChangesFor: How long after one power change lands
    ///     it ignores the next.
    ///   - mutedAsItComesOnFor: How long the volume reads muted once it
    ///     comes on.
    ///   - hasUSBInput: False for an LSX, which has no USB input.
    public init(
        volume: VolumeState,
        source: SourceByte,
        hasPairedBluetooth: Bool = false,
        keepsInputOnPowerOn: Bool = false,
        hasUSBInput: Bool = true,
        clock: SpeakerClock = SimulatedClock(),
        powerChangeTime: Duration = .zero,
        ignoresPowerChangesFor: Duration = .zero,
        mutedAsItComesOnFor: Duration = .zero
    ) {
        self.volumeByte = VolumeCoding.encode(level: volume.level, isMuted: volume.isMuted)
        self.sourceByte = source.encode()
        self.hasPairedBluetooth = hasPairedBluetooth
        self.keepsInputOnPowerOn = keepsInputOnPowerOn
        self.hasUSBInput = hasUSBInput
        self.clock = clock
        self.powerChangeTime = powerChangeTime
        self.ignoresPowerChangesFor = ignoresPowerChangesFor
        self.mutedAsItComesOnFor = mutedAsItComesOnFor
    }

    public func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        guard !hasCrashed else {
            throw KEFError.connectionFailed("simulated speaker crashed (power off with 20 min standby)")
        }
        let bytes = [UInt8](data)
        if bytes == [UInt8](KEFCommand.getVolume()) {
            return reply(register: KEFCommand.volumeRegister, value: volumeByteAsRead)
        }
        if bytes == [UInt8](KEFCommand.getSource()) {
            return reply(register: KEFCommand.sourceRegister, value: source.encode())
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

    /// The volume as a read reports it: muted for a moment as it comes on.
    private var volumeByteAsRead: UInt8 {
        landPowerChange()
        guard let cameOnAt, clock.now < cameOnAt + mutedAsItComesOnFor else { return volumeByte }
        return VolumeCoding.encode(level: volume.level, isMuted: true)
    }

    /// Every write is acked: the real speaker acks the ones it ignores too.
    private func write(source new: SourceByte) throws {
        if !new.isPoweredOn && new.standby == .twentyMinutes {
            hasCrashed = true
            throw KEFError.connectionFailed("simulated speaker crashed (power off with 20 min standby)")
        }
        let current = source
        guard powerChange == nil else { return }  // booting or shutting down
        if new.isPoweredOn != current.isPoweredOn {
            startPowerChange(to: new, from: current)
            return
        }
        guard current.isPoweredOn else { return }  // off: ignored
        sourceByte = withInputRules(new, from: current).encode()
    }

    private func startPowerChange(to new: SourceByte, from current: SourceByte) {
        if let landed = lastPowerChangeLanded, clock.now < landed + ignoresPowerChangesFor {
            return
        }
        var landing = new
        if new.isPoweredOn && keepsInputOnPowerOn {
            landing = landing.with(input: current.input)
        }
        powerChange = (withInputRules(landing, from: current), clock.now + powerChangeTime)
        landPowerChange()
    }

    /// Finish a power change whose time has come.
    private func landPowerChange() {
        guard let change = powerChange, clock.now >= change.landsAt else { return }
        sourceByte = change.source.encode()
        powerChange = nil
        lastPowerChangeLanded = change.landsAt
        if change.source.isPoweredOn { cameOnAt = change.landsAt }
    }

    /// The byte a write lands on: with no USB it keeps the input it had,
    /// and Bluetooth reads as paired or unpaired.
    private func withInputRules(_ source: SourceByte, from current: SourceByte) -> SourceByte {
        if source.input == .usb && !hasUSBInput { return source.with(input: current.input) }
        guard source.input.isSameInput(as: .bluetoothPaired) else { return source }
        return source.with(input: hasPairedBluetooth ? .bluetoothPaired : .bluetoothUnpaired)
    }

    /// A GET reply: `52 <register> 81 <value> <checksum>`. The checksum
    /// is left at 0: the controller never reads it.
    private func reply(register: UInt8, value: UInt8) -> Data {
        Data([0x52, register, 0x81, value, 0x00])
    }

    /// The speaker's acknowledgement of a write.
    private static let ack = Data([0x52, 0x11, 0xFF])
}
