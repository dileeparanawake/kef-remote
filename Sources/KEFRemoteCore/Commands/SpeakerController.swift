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
/// Operations are async because they involve network I/O (send command,
/// await response).
public class SpeakerController {
    private let connection: SpeakerConnection

    public init(connection: SpeakerConnection) {
        self.connection = connection
    }

    // MARK: - Volume

    /// Read the current volume level and mute state from the speaker.
    public func getVolume() async throws -> VolumeState {
        let response = try await connection.send(KEFCommand.getVolume(), expectResponseBytes: KEFCommand.getResponseSize)
        guard let byte = KEFCommand.parseResponse(response) else {
            throw KEFError.invalidResponse
        }
        return VolumeCoding.decode(byte)
    }

    /// Set the volume to an absolute level (0-100). Clamped.
    public func setVolume(_ level: Int) async throws {
        let byte = VolumeCoding.encode(level: level, isMuted: false)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Raise the volume by `amount` percent. Preserves mute state.
    public func raiseVolume(by amount: Int) async throws {
        let current = try await getVolume()
        let newLevel = min(current.level + amount, 100)
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Lower the volume by `amount` percent. Preserves mute state.
    public func lowerVolume(by amount: Int) async throws {
        let current = try await getVolume()
        let newLevel = max(current.level - amount, 0)
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Mute

    /// Mute the speaker. No-op if already muted.
    public func mute() async throws {
        let current = try await getVolume()
        guard !current.isMuted else { return }
        let byte = VolumeCoding.encode(level: current.level, isMuted: true)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Unmute the speaker. No-op if already unmuted.
    public func unmute() async throws {
        let current = try await getVolume()
        guard current.isMuted else { return }
        let byte = VolumeCoding.encode(level: current.level, isMuted: false)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Toggle mute state. If muted, unmute. If unmuted, mute.
    public func toggleMute() async throws {
        let current = try await getVolume()
        let byte = VolumeCoding.encode(level: current.level, isMuted: !current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Power

    /// Power on the speaker. Reads the source byte and sets the power bit.
    /// Preserves all other source byte fields (input, standby, inverse).
    public func powerOn() async throws {
        let source = try await readSourceByte()
        let modified = source.with(isPoweredOn: true)
        _ = try await connection.send(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    /// Power off the speaker.
    ///
    /// **Standby crash workaround:** If the speaker's standby is set to
    /// 20 minutes, we switch it to 60 minutes first. All KEF speakers
    /// crash their control server when powered off with 20-minute standby.
    ///
    /// Reference: Perl `kefctl` lines 222-229.
    public func powerOff() async throws {
        var source = try await readSourceByte()

        // Workaround: 20-minute standby crashes the speaker on power-off.
        // Switch to 60 minutes first, then power off.
        if source.standby == .twentyMinutes {
            let standbyFix = source.with(standby: .sixtyMinutes)
            _ = try await connection.send(KEFCommand.setSource(standbyFix.encode()), expectResponseBytes: KEFCommand.setResponseSize)
            source = standbyFix
        }

        let modified = source.with(isPoweredOn: false)
        _ = try await connection.send(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Input

    /// Read the current input source.
    public func getInput() async throws -> InputSource {
        let source = try await readSourceByte()
        return source.input
    }

    /// Set the input source. Preserves power, standby, and inverse settings.
    public func setInput(_ input: InputSource) async throws {
        let source = try await readSourceByte()
        let modified = source.with(input: input)
        _ = try await connection.send(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Standby

    /// Read the current standby timeout mode.
    public func getStandby() async throws -> StandbyMode {
        let source = try await readSourceByte()
        return source.standby
    }

    /// Set the standby timeout mode. Preserves other source byte fields.
    public func setStandby(_ mode: StandbyMode) async throws {
        let source = try await readSourceByte()
        let modified = source.with(standby: mode)
        _ = try await connection.send(KEFCommand.setSource(modified.encode()), expectResponseBytes: KEFCommand.setResponseSize)
    }

    // MARK: - Status

    /// Read the full speaker status (volume, mute, power, input, standby).
    public func getStatus() async throws -> SpeakerStatus {
        let volume = try await getVolume()
        let source = try await readSourceByte()
        return SpeakerStatus(
            volume: volume,
            isPoweredOn: source.isPoweredOn,
            isInversed: source.isInversed,
            input: source.input,
            standby: source.standby
        )
    }

    // MARK: - Private helpers

    /// Read and decode the current source byte from the speaker.
    private func readSourceByte() async throws -> SourceByte {
        let response = try await connection.send(KEFCommand.getSource(), expectResponseBytes: KEFCommand.getResponseSize)
        guard let byte = KEFCommand.parseResponse(response) else {
            throw KEFError.invalidResponse
        }
        return SourceByte(byte: byte)
    }
}
