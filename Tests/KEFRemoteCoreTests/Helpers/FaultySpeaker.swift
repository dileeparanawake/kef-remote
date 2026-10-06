import Foundation
@testable import KEFRemoteCore

/// A ``SimulatedSpeaker`` that misbehaves on cue, to test how the check
/// handles a speaker that gets something wrong.
final class FaultySpeaker: SpeakerConnection {
    let speaker: SimulatedSpeaker

    /// Writes it acknowledges but does not apply.
    var ignoresWrite: (Data) -> Bool = { _ in false }

    /// Sends that fail with a timeout. Asked before each send, so a test
    /// can fail just one.
    var failsSend: (Data) -> Bool = { _ in false }

    /// Volume reads it answers with this instead, when not nil.
    var volumeRead: () -> VolumeState? = { nil }

    init(_ speaker: SimulatedSpeaker) {
        self.speaker = speaker
    }

    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        if failsSend(data) {
            throw KEFError.commandTimeout
        }
        if ignoresWrite(data) {
            return Data([0x52, 0x11, 0xFF])
        }
        if data == KEFCommand.getVolume(), let volume = volumeRead() {
            let byte = VolumeCoding.encode(level: volume.level, isMuted: volume.isMuted)
            return Data([0x52, KEFCommand.volumeRegister, 0x81, byte, 0x00])
        }
        return try await speaker.send(data, expectResponseBytes: expectResponseBytes)
    }
}

extension Data {
    /// A volume write that mutes (the byte is 128 or more).
    var isMutingVolumeWrite: Bool {
        count == 4 && self[1] == KEFCommand.volumeRegister && self[0] == 0x53 && self[3] >= 128
    }

    /// A write to the source byte.
    var isSourceWrite: Bool {
        count == 4 && self[0] == 0x53 && self[1] == KEFCommand.sourceRegister
    }

    /// A source write with the power bit on (clear): it turns the speaker
    /// on, or keeps it on.
    var isPowerOnWrite: Bool {
        isSourceWrite && SourceByte(byte: self[3]).isPoweredOn
    }
}
