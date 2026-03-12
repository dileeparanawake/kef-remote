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
/// full hex dump.
///
/// Operations are async because they involve network I/O (send command,
/// await response).
public class SpeakerController {
    private let connection: SpeakerConnection
    private let log: KEFLogHandler

    public init(connection: SpeakerConnection, log: @escaping KEFLogHandler = { _, _ in }) {
        self.connection = connection
        self.log = log
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
        let response = try await connection.send(command, expectResponseBytes: expectResponseBytes)
        log(.debug, "RECV: \(response.hexString)")

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

    /// Read the current source byte (power, input, standby, inverse) from the speaker.
    public func getPowerState() async throws -> SourceByte {
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
        let source = try await getPowerState()
        return SpeakerStatus(
            volume: volume,
            isPoweredOn: source.isPoweredOn,
            isInversed: source.isInversed,
            input: source.input,
            standby: source.standby
        )
    }

    // MARK: - Volume

    /// Read the current volume level and mute state from the speaker.
    /// Calls `getVolumeState()` — kept for compatibility with existing callers.
    public func getVolume() async throws -> VolumeState {
        try await getVolumeState()
    }

    /// Set the volume to an absolute level (0-100). Clamped.
    public func setVolume(_ level: Int) async throws {
        let clamped = min(max(level, 0), 100)
        log(.info, "setVolume: \(clamped)%")
        let byte = VolumeCoding.encode(level: clamped, isMuted: false)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Raise the volume by `amount` percent. Preserves mute state.
    public func raiseVolume(by amount: Int) async throws {
        let current = try await getVolumeState()
        let newLevel = min(current.level + amount, 100)
        log(.info, "raiseVolume: \(current.level)%\(current.isMuted ? " [muted]" : "") → \(newLevel)%")
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Lower the volume by `amount` percent. Preserves mute state.
    public func lowerVolume(by amount: Int) async throws {
        let current = try await getVolumeState()
        let newLevel = max(current.level - amount, 0)
        log(.info, "lowerVolume: \(current.level)%\(current.isMuted ? " [muted]" : "") → \(newLevel)%")
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
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
        let byte = VolumeCoding.encode(level: current.level, isMuted: true)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Unmute the speaker. No-op if already unmuted.
    public func unmute() async throws {
        let current = try await getVolumeState()
        guard current.isMuted else {
            log(.info, "unmute: already unmuted — no-op")
            return
        }
        log(.info, "unmute: muted → \(current.level)%")
        let byte = VolumeCoding.encode(level: current.level, isMuted: false)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Toggle mute state. If muted, unmute. If unmuted, mute.
    public func toggleMute() async throws {
        let current = try await getVolumeState()
        let toggled = !current.isMuted
        log(.info, "toggleMute: \(current.isMuted ? "muted" : "unmuted") → \(toggled ? "muted" : "unmuted")")
        let byte = VolumeCoding.encode(level: current.level, isMuted: toggled)
        _ = try await sendAndReceive(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Power

    /// Power on the speaker. Reads the source byte and sets the power bit.
    /// Preserves all other source byte fields (input, standby, inverse).
    public func powerOn() async throws {
        log(.info, "powerOn")
        let source = try await getPowerState()
        let modified = source.with(isPoweredOn: true)
        _ = try await sendAndReceive(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
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
        var source = try await getPowerState()

        // Workaround: 20-minute standby crashes the speaker on power-off.
        // Switch to 60 minutes first, then power off.
        if source.standby == .twentyMinutes {
            log(.info, "powerOff: standby=20min — switching to 60min first (crash workaround)")
            let standbyFix = source.with(standby: .sixtyMinutes)
            _ = try await sendAndReceive(KEFCommand.setSource(standbyFix.encode()), expectResponseBytes: KEFCommand.setResponseSize)
            source = standbyFix
        }

        let modified = source.with(isPoweredOn: false)
        _ = try await sendAndReceive(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Input

    /// Read the current input source.
    public func getInput() async throws -> InputSource {
        let source = try await getPowerState()
        log(.info, "input: \(source.input)")
        return source.input
    }

    /// Set the input source. Preserves power, standby, and inverse settings.
    public func setInput(_ input: InputSource) async throws {
        log(.info, "setInput: \(input)")
        let source = try await getPowerState()
        let modified = source.with(input: input)
        _ = try await sendAndReceive(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Standby

    /// Read the current standby timeout mode.
    public func getStandby() async throws -> StandbyMode {
        let source = try await getPowerState()
        log(.info, "standby: \(source.standby)")
        return source.standby
    }

    /// Set the standby timeout mode. Preserves other source byte fields.
    public func setStandby(_ mode: StandbyMode) async throws {
        log(.info, "setStandby: \(mode)")
        let source = try await getPowerState()
        let modified = source.with(standby: mode)
        _ = try await sendAndReceive(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Status

    /// Read the full speaker status. Calls `getState()` — kept for compatibility.
    public func getStatus() async throws -> SpeakerStatus {
        try await getState()
    }
}
