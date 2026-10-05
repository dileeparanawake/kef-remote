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
/// `onReply`: the live connected state the menu bar shows.
///
/// Operations are async because they involve network I/O (send command,
/// await response).
public class SpeakerController {
    private let connection: SpeakerConnection
    let log: KEFLogHandler
    private let onReply: (SpeakerReply) -> Void

    /// - Parameter onReply: Called after every send, on the caller's
    ///   task, with whether the speaker answered.
    public init(
        connection: SpeakerConnection,
        log: @escaping KEFLogHandler = { _, _ in },
        onReply: @escaping (SpeakerReply) -> Void = { _ in }
    ) {
        self.connection = connection
        self.log = log
        self.onReply = onReply
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
        let response: Data
        do {
            response = try await connection.send(command, expectResponseBytes: expectResponseBytes)
        } catch {
            // An empty read (invalidResponse) says nothing about the link,
            // so only connection failures count as unreachable.
            if (error as? KEFError)?.isConnectionFailure ?? true {
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
        return source
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
        let current = try await getVolumeState()
        let newLevel = min(current.level + amount, 100)
        log(.info, "raiseVolume: \(current.level)%\(current.isMuted ? " [muted]" : "") → \(newLevel)%")
        try await writeVolume(level: newLevel, isMuted: current.isMuted)
    }

    /// Lower the volume by `amount` percent. Preserves mute state.
    public func lowerVolume(by amount: Int) async throws {
        let current = try await getVolumeState()
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
        let current = try await getVolumeState()
        let toggled = !current.isMuted
        log(.info, "toggleMute: \(current.isMuted ? "muted" : "unmuted") → \(toggled ? "muted" : "unmuted")")
        try await writeVolume(level: current.level, isMuted: toggled)
    }

    // MARK: - Power

    /// Power on the speaker. Reads the source byte and sets the power bit.
    /// Preserves all other source byte fields (input, standby, inverse).
    public func powerOn() async throws {
        log(.info, "powerOn")
        let source = try await getSourceByte()
        let modified = source.with(isPoweredOn: true)
        try await writeSource(modified)
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
        var source = try await getSourceByte()

        // Workaround: 20-minute standby crashes the speaker on power-off.
        // Switch to 60 minutes first, then power off.
        if source.standby == .twentyMinutes {
            log(.info, "powerOff: standby=20min — switching to 60min first (crash workaround)")
            let standbyFix = source.with(standby: .sixtyMinutes)
            try await writeSource(standbyFix)
            source = standbyFix
        }

        let modified = source.with(isPoweredOn: false)
        try await writeSource(modified)
    }

    // MARK: - Input

    /// Read the current input source.
    public func getInput() async throws -> InputSource {
        let source = try await getSourceByte()
        log(.info, "input: \(source.input)")
        return source.input
    }

    /// Set the input source. Preserves power, standby, and inverse settings.
    public func setInput(_ input: InputSource) async throws {
        log(.info, "setInput: \(input)")
        let source = try await getSourceByte()
        let modified = source.with(input: input)
        try await writeSource(modified)
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
}
