import Foundation

/// Full status snapshot of the speaker.
public struct SpeakerStatus: Equatable {
    public let volume: VolumeState
    public let isPoweredOn: Bool
    public let isInversed: Bool
    public let input: InputSource
    public let standby: StandbyMode

    public init(volume: VolumeState, isPoweredOn: Bool, isInversed: Bool, input: InputSource, standby: StandbyMode) {
        self.volume = volume
        self.isPoweredOn = isPoweredOn
        self.isInversed = isInversed
        self.input = input
        self.standby = standby
    }
}

/// High-level interface for controlling a KEF speaker.
///
/// All operations go through a `SpeakerConnection`, which abstracts
/// the TCP socket. This allows tests to inject a mock connection.
///
/// Every send/receive passes through `sendAndReceive()`, which logs
/// hex bytes at `.debug` level and validates the response shape before
/// returning. Invalid responses are logged at `.error` level with a
/// full hex dump. After each send it reports a ``SpeakerReply`` to
/// `onReply`: the live connected state the menu bar shows. Each source
/// byte it reads, or writes and the speaker acks, goes to `onSourceByte`,
/// so the menu can tick the input without reading it again.
///
/// Volume up, down and mute read the volume first. Just after power on,
/// a muted read is read again (``PowerOnMuteGuard``). Play/pause, next
/// and previous go only on Wi-Fi and Bluetooth (``sendPlayback(_:)``).
///
/// Operations are async because they involve network I/O (send command,
/// await response).
public class SpeakerController {
    private let connection: SpeakerConnection
    let log: KEFLogHandler
    private let onReply: (SpeakerReply) -> Void
    private let onSourceByte: (SourceByte) -> Void
    private let clock: SpeakerClock
    private var powerOnMuteGuard = PowerOnMuteGuard()
    /// One power toggle at a time, and none straight after another. The
    /// lock is there because presses that come together call
    /// ``togglePower(applying:)`` from several tasks at once.
    private var powerToggleGuard = PowerToggleGuard()
    private let powerToggleLock = NSLock()
    /// The source byte last read, or written and acked: play/pause uses
    /// it to skip a read when it shows the speaker on Wi-Fi or Bluetooth.
    private var lastSourceByte: SourceByte?
    /// When ``lastSourceByte`` was read or acked, on ``clock``.
    private var lastSourceByteAt: Duration?
    /// Sends still waiting for the speaker's reply. The connection reads
    /// replies in order, so a second exchange on top would take the
    /// first's reply: the menu-open read waits for none (``MenuOpenRead``).
    private var exchangesInFlight = 0

    /// - Parameters:
    ///   - onReply: Called after every send, on the caller's task, with
    ///     whether the speaker answered.
    ///   - onSourceByte: Called on the caller's task with the speaker's
    ///     source byte each time it is known: after a read, and after a
    ///     write the speaker acked.
    ///   - clock: Times the wait before reading the volume again after
    ///     power on. Share the simulated speaker's in tests.
    public init(
        connection: SpeakerConnection,
        log: @escaping KEFLogHandler = { _, _ in },
        onReply: @escaping (SpeakerReply) -> Void = { _ in },
        onSourceByte: @escaping (SourceByte) -> Void = { _ in },
        clock: SpeakerClock = RealSpeakerClock()
    ) {
        self.connection = connection
        self.log = log
        self.onReply = onReply
        self.onSourceByte = onSourceByte
        self.clock = clock
    }

    // MARK: - Core: send and receive

    /// Send a command, receive the response, validate its shape, and log both directions.
    ///
    /// - Logs sent bytes at `.debug` level
    /// - Logs received bytes at `.debug` level
    /// - Validates GET responses (5 bytes, correct header) and SET acks (3 bytes, `52 11 FF`)
    /// - Logs `.error` with full hex dump on validation failure, then throws
    private func sendAndReceive(_ command: Data, expectResponseBytes: Int) async throws -> Data {
        log(.debug, "SEND: \(command.hexString)")
        exchangesInFlight += 1
        defer { exchangesInFlight -= 1 }
        let response: Data
        do {
            response = try await connection.send(command, expectResponseBytes: expectResponseBytes)
        } catch {
            // An empty read (invalidResponse) says nothing about the link,
            // so only connection failures count as unreachable.
            if LocalNetworkPermission.isDenied(by: error) {
                onReply(.localNetworkBlocked("\(error)"))
            } else if (error as? KEFError)?.isConnectionFailure ?? true {
                onReply(.unreachable("\(error)"))
            }
            throw error
        }
        log(.debug, "RECV: \(response.hexString)")
        // Any bytes back mean the speaker is there, even if badly shaped.
        onReply(.answered)

        do {
            if expectResponseBytes == KEFCommand.getResponseSize {
                // Extract the queried register from the command (byte[1] of a GET command)
                let register: UInt8 = command.count >= 2 ? command[1] : 0
                try KEFCommand.validateGetResponse(response, register: register)
            } else {
                try KEFCommand.validateSetResponse(response)
            }
        } catch {
            log(.error, "Invalid response (expected \(expectResponseBytes) bytes): \(response.hexString)")
            throw error
        }

        return response
    }

    /// Write a volume byte and wait for the speaker's ack.
    private func writeVolume(level: Int, isMuted: Bool) async throws {
        let byte = VolumeCoding.encode(level: level, isMuted: isMuted)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Write a whole source byte and wait for the speaker's ack.
    private func writeSource(_ source: SourceByte) async throws {
        _ = try await sendAndReceive(KEFCommand.setSource(source.encode()), expectResponseBytes: KEFCommand.setResponseSize)
        noteSourceByte(source)
    }

    /// Keep the source byte the speaker has now, and pass it on to `onSourceByte`.
    private func noteSourceByte(_ source: SourceByte) {
        lastSourceByte = source
        lastSourceByteAt = clock.now
        onSourceByte(source)
    }

    // MARK: - Menu open

    /// Whether a command is waiting for the speaker's reply.
    public var isExchangeInFlight: Bool { exchangesInFlight > 0 }

    /// Time since the source byte was last read, or written and acked;
    /// nil before the first.
    public var sourceByteAge: Duration? { lastSourceByteAt.map { clock.now - $0 } }

    /// Whether opening the menu should read the source byte now. The
    /// caller logs the answer and, if it reads, calls ``getSourceByte()``.
    ///
    /// - Parameter isConnected: The speaker answered the last exchange.
    public func menuOpenRead(isConnected: Bool) -> MenuOpenRead {
        MenuOpenRead(isConnected: isConnected, isExchangeInFlight: isExchangeInFlight, sourceByteAge: sourceByteAge)
    }

    // MARK: - State reads

    /// Read the current volume level and mute state from the speaker.
    public func getVolumeState() async throws -> VolumeState {
        let response = try await sendAndReceive(KEFCommand.getVolume(), expectResponseBytes: KEFCommand.getResponseSize)
        guard let byte = KEFCommand.parseResponse(response) else {
            throw KEFError.invalidResponse
        }
        let state = VolumeCoding.decode(byte)
        log(.info, "volume: \(state.level)%\(state.isMuted ? " [muted]" : "")")
        return state
    }

    /// Read the whole source byte (power, input, standby, inverse) from the speaker.
    public func getSourceByte() async throws -> SourceByte {
        let response = try await sendAndReceive(KEFCommand.getSource(), expectResponseBytes: KEFCommand.getResponseSize)
        guard let byte = KEFCommand.parseResponse(response) else {
            throw KEFError.invalidResponse
        }
        let source = SourceByte(byte: byte)
        log(.info, "source: power=\(source.isPoweredOn ? "on" : "off") input=\(source.input) standby=\(source.standby)")
        powerOnMuteGuard.noteRead(source, at: clock.now)
        noteSourceByte(source)
        return source
    }

    /// Read the volume for a press that keeps or flips the mute it reads.
    /// Just after power on, a muted read is read again a second later and
    /// the second read is used: see ``PowerOnMuteGuard``.
    private func getVolumeStateForPress(_ command: String) async throws -> VolumeState {
        let first = try await getVolumeState()
        let now = clock.now
        guard powerOnMuteGuard.shouldReadAgain(first, at: now) else { return first }
        let since = powerOnMuteGuard.sincePowerOn(at: now).map { "\($0.components.seconds) s" } ?? "just"
        log(.info, "\(command): read muted \(since) after power on; reading again in "
            + "\(PowerOnMuteGuard.readAgainAfter.components.seconds) s (the speaker can show muted for a moment as it comes on)")
        await clock.sleep(for: PowerOnMuteGuard.readAgainAfter)
        let second = try await getVolumeState()
        let verdict = second.isMuted ? "still muted (keeping the mute)" : "not muted (it was the power-on moment)"
        log(.info, "\(command): read again: \(second.level)%\(second.isMuted ? " muted" : ""), \(verdict)")
        return second
    }

    /// Read the full speaker state: volume then source, sequentially.
    ///
    /// Each GET waits for its response before the next is sent — no interleaving.
    /// Returns a combined `SpeakerStatus`.
    public func getState() async throws -> SpeakerStatus {
        log(.info, "getState: reading volume and source")
        let volume = try await getVolumeState()
        let source = try await getSourceByte()
        return SpeakerStatus(
            volume: volume,
            isPoweredOn: source.isPoweredOn,
            isInversed: source.isInversed,
            input: source.input,
            standby: source.standby
        )
    }

    // MARK: - Volume

    /// Set the volume to an absolute level (0-100). Clamped.
    public func setVolume(_ level: Int) async throws {
        let clamped = min(max(level, 0), 100)
        log(.info, "setVolume: \(clamped)%")
        try await writeVolume(level: clamped, isMuted: false)
    }

    /// Raise the volume by `amount` percent. Preserves mute state.
    public func raiseVolume(by amount: Int) async throws {
        let current = try await getVolumeStateForPress("raiseVolume")
        let newLevel = min(current.level + amount, 100)
        log(.info, "raiseVolume: \(current.level)%\(current.isMuted ? " [muted]" : "") → \(newLevel)%")
        try await writeVolume(level: newLevel, isMuted: current.isMuted)
    }

    /// Lower the volume by `amount` percent. Preserves mute state.
    public func lowerVolume(by amount: Int) async throws {
        let current = try await getVolumeStateForPress("lowerVolume")
        let newLevel = max(current.level - amount, 0)
        log(.info, "lowerVolume: \(current.level)%\(current.isMuted ? " [muted]" : "") → \(newLevel)%")
        try await writeVolume(level: newLevel, isMuted: current.isMuted)
    }

    // MARK: - Mute

    /// Mute the speaker. No-op if already muted.
    public func mute() async throws {
        let current = try await getVolumeState()
        guard !current.isMuted else {
            log(.info, "mute: already muted — no-op")
            return
        }
        log(.info, "mute: \(current.level)% → muted")
        try await writeVolume(level: current.level, isMuted: true)
    }

    /// Unmute the speaker. No-op if already unmuted.
    public func unmute() async throws {
        let current = try await getVolumeState()
        guard current.isMuted else {
            log(.info, "unmute: already unmuted — no-op")
            return
        }
        log(.info, "unmute: muted → \(current.level)%")
        try await writeVolume(level: current.level, isMuted: false)
    }

    /// Toggle mute state. If muted, unmute. If unmuted, mute.
    public func toggleMute() async throws {
        let current = try await getVolumeStateForPress("toggleMute")
        let toggled = !current.isMuted
        log(.info, "toggleMute: \(current.isMuted ? "muted" : "unmuted") → \(toggled ? "muted" : "unmuted")")
        try await writeVolume(level: current.level, isMuted: toggled)
    }

    // MARK: - Power

    /// Power on the speaker. Reads the source byte, then writes it back
    /// with the power bit set and what `settings` chooses for turning on
    /// (see ``SpeakerSettings/powerOnByte(from:)``). Other fields are kept.
    public func powerOn(applying settings: SpeakerSettings = SpeakerSettings()) async throws {
        log(.info, "powerOn")
        try await writePowerOn(from: try await getSourceByte(), applying: settings)
    }

    /// Power off the speaker.
    ///
    /// **Standby crash workaround:** If the speaker's standby is set to
    /// 20 minutes, we switch it to 60 minutes first. All KEF speakers
    /// crash their control server when powered off with 20-minute standby.
    ///
    /// Reference: Perl `kefctl` lines 222-229.
    public func powerOff() async throws {
        log(.info, "powerOff")
        try await writePowerOff(from: try await getSourceByte())
    }

    /// Turn the speaker off if it is on, or on if it is off. Reads the
    /// source byte once and decides from its power bit, so the power-off
    /// side keeps the 20-minute standby workaround. Turning on applies
    /// `settings` in the same write, as ``powerOn(applying:)`` does.
    ///
    /// Sends nothing while another toggle is in flight, or straight after
    /// one (``PowerToggleGuard``): a burst of presses is one toggle.
    @discardableResult
    public func togglePower(applying settings: SpeakerSettings = SpeakerSettings()) async throws -> PowerToggleResult {
        if let refusal = powerToggleLock.withLock({ powerToggleGuard.start(at: clock.now) }) {
            log(.info, "togglePower: ignored, \(refusal.reason)")
            return .ignored(refusal)
        }
        defer { powerToggleLock.withLock { powerToggleGuard.finish(at: clock.now) } }

        let source = try await getSourceByte()
        log(.info, "togglePower: \(source.isPoweredOn ? "on → off" : "off → on")")
        if source.isPoweredOn {
            try await writePowerOff(from: source)
            return .turnedOff
        }
        try await writePowerOn(from: source, applying: settings)
        return .turnedOn
    }

    private func writePowerOn(from source: SourceByte, applying settings: SpeakerSettings) async throws {
        let byte = settings.powerOnByte(from: source)
        if !source.isPoweredOn { powerOnMuteGuard.notePowerOnWrite(at: clock.now) }
        log(.info, "powerOn: sending power=on input=\(byte.input) standby=\(byte.standby) "
            + "(was input=\(source.input) standby=\(source.standby); "
            + "power-on input: \(settings.powerOnInput.label), standby: \(settings.standby.label))")
        try await writeSource(byte)
    }

    private func writePowerOff(from source: SourceByte) async throws {
        var source = source
        // Workaround: 20-minute standby crashes the speaker on power-off.
        // Switch to 60 minutes first, then power off.
        if source.standby == .twentyMinutes {
            log(.info, "powerOff: standby=20min — switching to 60min first (crash workaround)")
            let standbyFix = source.with(standby: .sixtyMinutes)
            try await writeSource(standbyFix)
            source = standbyFix
        }
        try await writeSource(source.with(isPoweredOn: false))
    }

    // MARK: - Input

    /// Read the current input source.
    public func getInput() async throws -> InputSource {
        let source = try await getSourceByte()
        log(.info, "input: \(source.input)")
        return source.input
    }

    /// How long Input ▸ reads back a switch before saying it didn't take.
    /// The real speaker showed every input switch at once.
    public static let inputReadBackLimit: Duration = .seconds(2)
    /// How often it reads back meanwhile.
    public static let inputReadBackInterval: Duration = .milliseconds(500)

    /// Switch the input from Input ▸, then read it back, so the HUD names
    /// the input the speaker is on, not the one asked for. A speaker that
    /// is off isn't sent it: it ignores input writes while off.
    public func switchInput(to input: InputSource) async throws -> InputSwitchResult {
        let source = try await getSourceByte()
        guard source.isPoweredOn else {
            log(.info, "switchInput: \(input.label) not sent: the speaker is off, and it ignores input while off")
            return .speakerOff
        }
        log(.info, "switchInput: \(source.input.label) -> \(input.label)")
        try await writeSource(source.with(input: input))
        let started = clock.now
        while true {
            let now = try await getSourceByte()
            if now.input.isSameInput(as: input) {
                log(.info, "switchInput: the speaker is on \(now.input.label)")
                return .switched(now.input)
            }
            let waited = clock.now - started
            if waited >= Self.inputReadBackLimit {
                log(.warning, "switchInput: asked for \(input.label), the speaker stayed on \(now.input.label) "
                    + "after \(waited.components.seconds) s (it may not have that input)")
                return .notTaken(asked: input, stayedOn: now.input)
            }
            await clock.sleep(for: Self.inputReadBackInterval)
        }
    }

    /// Set the input source. Preserves power, standby, and inverse settings.
    public func setInput(_ input: InputSource) async throws {
        let source = try await getSourceByte()
        log(.info, "setInput: \(source.input.label) -> \(input.label)")
        try await writeSource(source.with(input: input))
    }

    // MARK: - Playback

    /// Send play/pause, next or previous, on Wi-Fi or Bluetooth only: on
    /// Optical, Aux and USB another device plays, so nothing is sent.
    /// Nothing reads it back, so the ack is all it checks.
    ///
    /// It uses the last source byte when that shows Wi-Fi or Bluetooth.
    /// Otherwise it reads first: the speaker changes input by itself (AirPlay
    /// switches it to Wi-Fi), so a refusal never rests on an old byte.
    public func sendPlayback(_ command: PlaybackCommand) async throws -> PlaybackResult {
        let source: SourceByte
        let from: String
        if let known = lastSourceByte, known.isPoweredOn, known.input.hasPlayback {
            (source, from) = (known, "last read")
        } else {
            (source, from) = (try await getSourceByte(), "read now")
        }
        guard source.isPoweredOn else {
            log(.info, "\(command.name): not sent: the speaker is off")
            return .speakerOff
        }
        guard source.input.hasPlayback else {
            log(.info, "\(command.name): not sent: the speaker is on \(source.input.label), "
                + "and play/pause, next and previous work on Wi-Fi and Bluetooth")
            return .notOnThisInput(source.input)
        }
        log(.info, "\(command.name): sending on \(source.input.label) (\(from))")
        _ = try await sendAndReceive(KEFCommand.setPlayback(command), expectResponseBytes: KEFCommand.setResponseSize)
        return .sent
    }

    // MARK: - Left and right

    /// Swap the left and right speakers, or put them back. Preserves the
    /// other source byte fields. The speaker keeps it, so the app doesn't
    /// save it. Only reads when the speaker is already that way.
    public func setLeftRightSwapped(_ isSwapped: Bool) async throws {
        let source = try await getSourceByte()
        guard source.isInversed != isSwapped else {
            log(.info, "swap left and right: already \(isSwapped ? "on" : "off")")
            return
        }
        log(.info, "swap left and right: \(source.isInversed ? "on" : "off") -> \(isSwapped ? "on" : "off")")
        try await writeSource(source.with(isInversed: isSwapped))
    }

    // MARK: - Standby

    /// Read the current standby timeout mode.
    public func getStandby() async throws -> StandbyMode {
        let source = try await getSourceByte()
        log(.info, "standby: \(source.standby)")
        return source.standby
    }

    /// Set the standby timeout mode. Preserves other source byte fields.
    public func setStandby(_ mode: StandbyMode) async throws {
        log(.info, "setStandby: \(mode)")
        let source = try await getSourceByte()
        let modified = source.with(standby: mode)
        try await writeSource(modified)
    }

    /// Write the standby time `settings` asks for at this moment (see
    /// ``SpeakerSettings/standbyToWrite(for:)``), and log it with `reason`.
    /// Sends nothing for Don't change, and only reads when the speaker
    /// already has that time.
    public func applyStandby(_ settings: SpeakerSettings, for reason: StandbyReason) async throws {
        guard let mode = settings.standbyToWrite(for: reason) else {
            log(.info, "standby: \(settings.standby.label), leaving the speaker's (\(reason.rawValue))")
            return
        }
        let source = try await getSourceByte()
        guard source.standby != mode else {
            log(.info, "standby: already \(mode) (\(reason.rawValue))")
            return
        }
        // A write with the power bit off and 20 min standby is what crashes
        // the speaker (see writePowerOff). The power-on write sets it instead.
        guard source.isPoweredOn || mode != .twentyMinutes else {
            log(.info, "standby: not writing \(mode) while the speaker is off (it crashes); "
                + "the next power-on sets it (\(reason.rawValue))")
            return
        }
        log(.info, "standby: \(source.standby) -> \(mode) (\(reason.rawValue))")
        try await writeSource(source.with(standby: mode))
    }
}
