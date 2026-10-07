import Testing
import Foundation
@testable import KEFRemoteCore

/// Play/pause, next and previous: sent on Wi-Fi and Bluetooth only.
struct SpeakerControllerPlaybackTests {
    let onWiFi = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    let forty = VolumeState(level: 40, isMuted: false)
    let ack = Data([0x52, 0x11, 0xFF])

    private func sourceReply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    @Test func onWiFiItSendsPlayPauseAndChecksTheAck() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi), ack]
        let log = MockKEFLog()

        let result = try await SpeakerController(connection: mock, log: log.handler).sendPlayback(.playPause)

        #expect(result == .sent)
        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.setPlayback(.playPause)])
        #expect(mock.sentExpectedSizes.last == KEFCommand.setResponseSize)
        #expect(log.messages(at: .info).contains("play/pause: sending on Wi-Fi (read now)"))
    }

    @Test func nextAndPreviousSendTheirOwnBytes() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: onWiFi)
        let controller = SpeakerController(connection: speaker)

        _ = try await controller.sendPlayback(.next)
        _ = try await controller.sendPlayback(.previous)

        #expect(speaker.playbackReceived == [.next, .previous])
    }

    @Test func onBluetoothItSends() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: onWiFi.with(input: .bluetoothUnpaired))

        let result = try await SpeakerController(connection: speaker).sendPlayback(.playPause)

        #expect(result == .sent)
        #expect(speaker.playbackReceived == [.playPause])
    }

    /// Optical and Aux come from another device: nothing for the speaker to play.
    @Test func onOpticalItSendsNothingAndSaysWhy() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi.with(input: .optical))]
        let log = MockKEFLog()

        let result = try await SpeakerController(connection: mock, log: log.handler).sendPlayback(.playPause)

        #expect(result == .notOnThisInput(.optical))
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains(
            "play/pause: not sent: the speaker is on Optical, and play/pause, next and previous work on Wi-Fi and Bluetooth"
        ))
    }

    @Test func onAuxItSendsNothing() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: onWiFi.with(input: .aux))

        let result = try await SpeakerController(connection: speaker).sendPlayback(.next)

        #expect(result == .notOnThisInput(.aux))
        #expect(speaker.playbackReceived.isEmpty)
    }

    @Test func aSpeakerThatIsOffIsNotSentIt() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: onWiFi.with(isPoweredOn: false))
        let log = MockKEFLog()

        let result = try await SpeakerController(connection: speaker, log: log.handler).sendPlayback(.playPause)

        #expect(result == .speakerOff)
        #expect(speaker.playbackReceived.isEmpty)
        #expect(log.messages(at: .info).contains("play/pause: not sent: the speaker is off"))
    }

    /// The source byte the controller last read is used, so a press on
    /// Wi-Fi costs one exchange.
    @Test func itUsesTheLastSourceByteWhenThatAllowsIt() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi), ack]
        let log = MockKEFLog()
        let controller = SpeakerController(connection: mock, log: log.handler)
        _ = try await controller.getSourceByte()

        let result = try await controller.sendPlayback(.playPause)

        #expect(result == .sent)
        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.setPlayback(.playPause)])
        #expect(log.messages(at: .info).contains("play/pause: sending on Wi-Fi (last read)"))
    }

    /// AirPlay switches the speaker to Wi-Fi by itself, so a last read of
    /// Optical may be old: it reads again before saying no.
    @Test func itReadsAgainBeforeRefusingOnAnOldInput() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi.with(input: .optical)), sourceReply(onWiFi), ack]
        let controller = SpeakerController(connection: mock)
        _ = try await controller.getSourceByte()

        let result = try await controller.sendPlayback(.playPause)

        #expect(result == .sent)
        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.getSource(), KEFCommand.setPlayback(.playPause)])
    }

    /// A source byte the controller wrote and the speaker acked counts as known too.
    @Test func aSourceWriteCountsAsTheLastRead() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi.with(input: .optical)), ack, ack]
        let controller = SpeakerController(connection: mock)
        try await controller.setInput(.wifi)

        let result = try await controller.sendPlayback(.playPause)

        #expect(result == .sent)
        #expect(mock.sentCommands == [
            KEFCommand.getSource(), KEFCommand.setSource(onWiFi.encode()), KEFCommand.setPlayback(.playPause),
        ])
    }

    @Test func aBadAckFails() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [sourceReply(onWiFi), Data([0x00, 0x00, 0x00])]

        await #expect(throws: KEFError.invalidResponse) {
            _ = try await SpeakerController(connection: mock).sendPlayback(.playPause)
        }
    }
}
