import Foundation
@testable import KEFRemoteCore

/// A pretend speaker that takes a moment to answer each send and counts
/// how many exchanges reach it at once. The real one shares one TCP
/// connection between them, so two at once cross their replies (hand
/// test 6 Oct 2026, 18:36:38: "Invalid response ... 52 12 FF", then the
/// speaker refused every connection).
///
/// It holds the volume and source byte under a lock, so many tasks can
/// send at once, as the app's key presses do.
final class OverlapProbeSpeaker: SpeakerConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var volumeByte: UInt8
    private var sourceByte: UInt8
    private var inFlight = 0
    private var most = 0
    private var sent: [Data] = []
    private let replyDelay: Duration

    init(volume: VolumeState, source: SourceByte = SourceByte(byte: 0x02), replyDelay: Duration = .milliseconds(2)) {
        self.volumeByte = VolumeCoding.encode(level: volume.level, isMuted: volume.isMuted)
        self.sourceByte = source.encode()
        self.replyDelay = replyDelay
    }

    /// The most exchanges that were waiting for a reply at the same time.
    var mostAtOnce: Int { lock.withLock { most } }
    /// Every command sent so far, in order.
    var sentCommands: [Data] { lock.withLock { sent } }
    /// The volume it holds now.
    var volume: VolumeState { lock.withLock { VolumeCoding.decode(volumeByte) } }

    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        lock.withLock {
            inFlight += 1
            most = max(most, inFlight)
            sent.append(data)
        }
        defer { lock.withLock { inFlight -= 1 } }
        // Reads answer the value at the time of the read; the write lands
        // after the wait, like a reply coming back over the network.
        let readNow = lock.withLock { answerIfRead(data) }
        try await Task.sleep(for: replyDelay)
        if let readNow { return readNow }
        return try lock.withLock { try write(data) }
    }

    private func answerIfRead(_ data: Data) -> Data? {
        if data == KEFCommand.getVolume() { return Data([0x52, KEFCommand.volumeRegister, 0x81, volumeByte, 0x00]) }
        if data == KEFCommand.getSource() { return Data([0x52, KEFCommand.sourceRegister, 0x81, sourceByte, 0x00]) }
        return nil
    }

    private func write(_ data: Data) throws -> Data {
        guard data.count == 4, data[0] == 0x53 else { throw KEFError.invalidResponse }
        if data[1] == KEFCommand.volumeRegister { volumeByte = data[3] }
        if data[1] == KEFCommand.sourceRegister { sourceByte = data[3] }
        return Data([0x52, 0x11, 0xFF])
    }
}

extension Data {
    /// A GET (3 bytes), as opposed to a SET (4 bytes).
    var isRead: Bool { count == 3 }
}
