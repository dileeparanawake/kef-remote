import Foundation

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
        let response = try await connection.send(KEFCommand.getVolume())
        guard let byte = KEFCommand.parseResponse(response) else {
            throw KEFError.invalidResponse
        }
        return VolumeCoding.decode(byte)
    }

    /// Set the volume to an absolute level (0-100). Clamped.
    public func setVolume(_ level: Int) async throws {
        let byte = VolumeCoding.encode(level: level, isMuted: false)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }

    /// Raise the volume by `amount` percent. Preserves mute state.
    public func raiseVolume(by amount: Int) async throws {
        let current = try await getVolume()
        let newLevel = min(current.level + amount, 100)
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }

    /// Lower the volume by `amount` percent. Preserves mute state.
    public func lowerVolume(by amount: Int) async throws {
        let current = try await getVolume()
        let newLevel = max(current.level - amount, 0)
        let byte = VolumeCoding.encode(level: newLevel, isMuted: current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }

    // MARK: - Mute

    /// Mute the speaker. No-op if already muted.
    public func mute() async throws {
        let current = try await getVolume()
        guard !current.isMuted else { return }
        let byte = VolumeCoding.encode(level: current.level, isMuted: true)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }

    /// Unmute the speaker. No-op if already unmuted.
    public func unmute() async throws {
        let current = try await getVolume()
        guard current.isMuted else { return }
        let byte = VolumeCoding.encode(level: current.level, isMuted: false)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }

    /// Toggle mute state. If muted, unmute. If unmuted, mute.
    public func toggleMute() async throws {
        let current = try await getVolume()
        let byte = VolumeCoding.encode(level: current.level, isMuted: !current.isMuted)
        _ = try await connection.send(KEFCommand.setVolume(byte))
    }
}
