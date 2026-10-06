import Foundation

/// Passes every exchange on to the speaker and keeps a copy, so each
/// line of the check can show the bytes behind it.
final class RecordingConnection: SpeakerConnection {
    private struct Exchange {
        let sent: Data
        let reply: Data
        let isWrite: Bool
    }

    private let speaker: SpeakerConnection
    private var exchanges: [Exchange] = []

    init(_ speaker: SpeakerConnection) {
        self.speaker = speaker
    }

    /// Where the record is now. Pass it back to see what came after.
    var mark: Int { exchanges.count }

    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        let reply = try await speaker.send(data, expectResponseBytes: expectResponseBytes)
        exchanges.append(Exchange(
            sent: data, reply: reply, isWrite: expectResponseBytes == KEFCommand.setResponseSize
        ))
        return reply
    }

    /// The last write sent since `mark`.
    func lastWrite(since mark: Int) -> Data? {
        exchanges[mark...].last { $0.isWrite }?.sent
    }

    /// How many writes were sent since `mark`.
    func writeCount(since mark: Int) -> Int {
        exchanges[mark...].filter(\.isWrite).count
    }

    /// Each volume the speaker read back since `mark`, in order.
    func volumeReads(since mark: Int) -> [VolumeState] {
        exchanges[mark...]
            .filter { $0.sent == KEFCommand.getVolume() }
            .compactMap { KEFCommand.parseResponse($0.reply).map(VolumeCoding.decode) }
    }

    /// The speaker's reply to the last read since `mark`.
    func lastReadReply(since mark: Int) -> Data? {
        exchanges[mark...].last { !$0.isWrite }?.reply
    }
}
