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
        return try await speaker.send(data, expectResponseBytes: expectResponseBytes)
    }
}

extension Data {
    /// A volume write that mutes (the byte is 128 or more).
    var isMutingVolumeWrite: Bool {
        count == 4 && self[1] == KEFCommand.volumeRegister && self[0] == 0x53 && self[3] >= 128
    }

    /// A source write that turns the speaker on (power bit clear).
    var isPowerOnWrite: Bool {
        count == 4 && self[1] == KEFCommand.sourceRegister && self[0] == 0x53 && SourceByte(byte: self[3]).isPoweredOn
    }
}
