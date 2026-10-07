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
///
/// And how the real gen-1 LSX fell over under bursts (hand test and logs,
/// 6 Oct 2026), so the tests and the dry run catch a change that would
/// knock it over again:
/// - Its one connection is one byte stream, answered in order. A request
///   that arrives before the last reply was read crosses the replies: the
///   first reader takes the other's bytes (the app read `52 12 FF`, an
///   ack's length, where it expected a 5-byte volume reply).
/// - Overlapping exchanges, more than ``maxConnectionOpensInWindow``
///   connection opens within ``connectionOpenWindow``, or more than
///   ``maxWritesInBurst`` writes within ``writeBurstWindow`` crash its
///   control server: every exchange and connection after that is refused
///   (TCP RST, "Connection refused") until ``powerCycleAtWall()``. Its
///   own standby (the KEF remote's on/off) doesn't bring it back.
///
/// Each reply takes `replyTime` on the shared clock, then a few task
/// switches (``yieldsWhileReplying``) in which another task can send on
/// top of it, as the app's key presses did. It is locked, so many tasks
/// can send at once.
public final class SimulatedSpeaker: SpeakerConnection, @unchecked Sendable {
    // MARK: Overload thresholds (hand test and logs, 6 Oct 2026)

    /// Two reconnects started together (18:36:38-41), and the control
    /// server refused every connection after. The app's reconnector opens
    /// at most one per 2 s, so the window is its first wait.
    public static let connectionOpenWindow: Duration = .seconds(2)
    /// Opens within ``connectionOpenWindow`` it takes; one more crashes it.
    public static let maxConnectionOpensInWindow = 3
    /// One press fired the power shortcut 176 times together: ~176 power
    /// writes in ~100 ms, and the control server stopped answering.
    public static let writeBurstWindow: Duration = .milliseconds(100)
    /// Writes within ``writeBurstWindow`` it takes; one more crashes it.
    /// Far below 176, and above anything one command sends at once.
    public static let maxWritesInBurst = 20
    /// Task switches between a request and reading its reply: the moment
    /// the reply is on the wire, when a request on top would overlap.
    public static let yieldsWhileReplying = 3
    /// How long a reply takes unless told otherwise. The real LSX took
    /// 60-230 ms (logs, 6 Oct 2026); quicker here, so a burst of writes
    /// one after another packs tighter than it could for real. With no
    /// time at all, a whole check would land in one instant: a burst.
    public static let defaultReplyTime: Duration = .milliseconds(10)

    private let lock = NSLock()
    private var volumeByte: UInt8
    private var sourceByte: UInt8
    private let hasPairedBluetooth: Bool
    private let keepsInputOnPowerOn: Bool
    private let hasUSBInput: Bool
    private let clock: SpeakerClock
    private let powerChangeTime: Duration
    private let ignoresPowerChangesFor: Duration
    private let mutedAsItComesOnFor: Duration
    private let replyTime: Duration

    /// A power change on its way: the byte it lands on, and when.
    private var powerChange: (source: SourceByte, landsAt: Duration)?
    /// When the last power change landed.
    private var lastPowerChangeLanded: Duration?
    /// When it last came on, for the moment it reads muted.
    private var cameOnAt: Duration?

    /// Why its control server crashed, until ``powerCycleAtWall()``.
    private var crash: Crash?
    /// Reply bytes sent and not yet read: the one connection's stream.
    private var unreadReplyBytes: [UInt8] = []
    /// Requests whose reply hasn't been read yet.
    private var exchangesInFlight = 0
    private var mostInFlight = 0
    /// When recent writes and connection opens arrived, for the bursts.
    private var recentWrites: [Duration] = []
    private var recentOpens: [Duration] = []

    /// How its control server went down.
    private enum Crash {
        /// Power off with 20-minute standby: it stops answering.
        case twentyMinuteStandby
        /// Too much at once: it refuses every connection.
        case overload(String)

        var error: KEFError {
            switch self {
            case .twentyMinuteStandby:
                return .connectionFailed("simulated speaker crashed (power off with 20 min standby)")
            case .overload:
                return .connectionRefused
            }
        }

        var reason: String {
            switch self {
            case .twentyMinuteStandby: return "power off with 20 min standby"
            case .overload(let reason): return reason
            }
        }
    }

    /// True once its control server crashed, until ``powerCycleAtWall()``.
    public var hasCrashed: Bool { lock.withLock { crash != nil } }
    /// Why it crashed, in words; nil while it answers.
    public var crashReason: String? { lock.withLock { crash?.reason } }
    /// The most exchanges that were waiting for a reply at once.
    public var mostExchangesAtOnce: Int { lock.withLock { mostInFlight } }

    /// What it holds now.
    public var volume: VolumeState { lock.withLock { VolumeCoding.decode(volumeByte) } }
    public var source: SourceByte { lock.withLock { currentSource } }

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
    ///   - replyTime: How long each reply takes on `clock`.
    public init(
        volume: VolumeState,
        source: SourceByte,
        hasPairedBluetooth: Bool = false,
        keepsInputOnPowerOn: Bool = false,
        hasUSBInput: Bool = true,
        clock: SpeakerClock = SimulatedClock(),
        powerChangeTime: Duration = .zero,
        ignoresPowerChangesFor: Duration = .zero,
        mutedAsItComesOnFor: Duration = .zero,
        replyTime: Duration = defaultReplyTime
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
        self.replyTime = replyTime
    }

    // MARK: - The connection

    /// Send a request, then read its reply off the stream once it has
    /// had time to come back. Another request in that moment overlaps.
    public func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        try request(data)
        await clock.sleep(for: replyTime)
        for _ in 0..<Self.yieldsWhileReplying { await Task.yield() }
        return try readReply(expectResponseBytes)
    }

    /// A connection opens. Refused once it has crashed, and a burst of
    /// opens crashes it. A new connection starts with no stray bytes.
    public func openConnection() throws {
        try lock.withLock {
            if let crash { throw crash.error }
            let now = clock.now
            recentOpens = recentOpens.filter { now - $0 < Self.connectionOpenWindow } + [now]
            if recentOpens.count > Self.maxConnectionOpensInWindow {
                crash = .overload("\(recentOpens.count) connection opens within "
                    + "\(Self.connectionOpenWindow.components.seconds) s")
                throw KEFError.connectionRefused
            }
            unreadReplyBytes = []
        }
    }

    /// The connection closes: replies not yet read are lost with it.
    public func closeConnection() {
        lock.withLock { unreadReplyBytes = [] }
    }

    /// Switch it off and on at the wall: the only thing that brings a
    /// crashed control server back. What it holds is kept.
    public func powerCycleAtWall() {
        lock.withLock {
            crash = nil
            unreadReplyBytes = []
            exchangesInFlight = 0
            recentWrites = []
            recentOpens = []
        }
    }

    /// A request arrives: answer it onto the stream. One that overlaps
    /// another exchange, or tips a burst of writes, crashes the control
    /// server; it was already taken, so it is still answered (crossed).
    func request(_ data: Data) throws {
        try lock.withLock {
            if let crash { throw crash.error }
            exchangesInFlight += 1
            mostInFlight = max(mostInFlight, exchangesInFlight)
            if exchangesInFlight > 1 {
                crash = .overload("\(exchangesInFlight) exchanges at once on its one connection")
            }
            if data.count == Self.writeSize { noteWrite() }
            do {
                unreadReplyBytes += try answer(data)
            } catch {
                exchangesInFlight -= 1
                throw error
            }
        }
    }

    /// Read the next `count` bytes off the stream: this request's reply,
    /// unless another overlapped it.
    func readReply(_ count: Int) throws -> Data {
        try lock.withLock {
            exchangesInFlight = max(exchangesInFlight - 1, 0)
            guard unreadReplyBytes.count >= count else {
                unreadReplyBytes = []
                throw KEFError.commandTimeout
            }
            let reply = Data(unreadReplyBytes.prefix(count))
            unreadReplyBytes.removeFirst(count)
            return reply
        }
    }

    /// A SET: the GET's 3 bytes and the value.
    private static let writeSize = 4

    /// Count a write towards a burst.
    private func noteWrite() {
        let now = clock.now
        recentWrites = recentWrites.filter { now - $0 < Self.writeBurstWindow } + [now]
        if recentWrites.count > Self.maxWritesInBurst, crash == nil {
            crash = .overload("\(recentWrites.count) writes within "
                + "\(Int(Self.writeBurstWindow / .milliseconds(1))) ms")
        }
    }

    // MARK: - The protocol (lock held)

    /// The reply to a request, after doing what it asks.
    private func answer(_ data: Data) throws -> [UInt8] {
        let bytes = [UInt8](data)
        if bytes == [UInt8](KEFCommand.getVolume()) {
            return reply(register: KEFCommand.volumeRegister, value: volumeByteAsRead)
        }
        if bytes == [UInt8](KEFCommand.getSource()) {
            return reply(register: KEFCommand.sourceRegister, value: currentSource.encode())
        }
        if bytes.count == Self.writeSize, data == KEFCommand.setVolume(bytes[3]) {
            volumeByte = bytes[3]
            return Self.ack
        }
        if bytes.count == Self.writeSize, data == KEFCommand.setSource(bytes[3]) {
            try write(source: SourceByte(byte: bytes[3]))
            return Self.ack
        }
        throw KEFError.invalidResponse
    }

    /// ``source``, with the lock held.
    private var currentSource: SourceByte {
        landPowerChange()
        return SourceByte(byte: sourceByte)
    }

    /// The volume as a read reports it: muted for a moment as it comes on.
    private var volumeByteAsRead: UInt8 {
        landPowerChange()
        guard let cameOnAt, clock.now < cameOnAt + mutedAsItComesOnFor else { return volumeByte }
        return VolumeCoding.encode(level: VolumeCoding.decode(volumeByte).level, isMuted: true)
    }

    /// Every write is acked: the real speaker acks the ones it ignores too.
    private func write(source new: SourceByte) throws {
        if !new.isPoweredOn && new.standby == .twentyMinutes {
            crash = .twentyMinuteStandby
            throw Crash.twentyMinuteStandby.error
        }
        let current = currentSource
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
    private func reply(register: UInt8, value: UInt8) -> [UInt8] {
        [0x52, register, 0x81, value, 0x00]
    }

    /// The speaker's acknowledgement of a write.
    private static let ack: [UInt8] = [0x52, 0x11, 0xFF]
}
