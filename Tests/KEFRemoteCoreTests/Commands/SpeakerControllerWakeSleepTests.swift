import Testing
import Foundation
@testable import KEFRemoteCore

/// Wake and sleep each run as one sequence: every step reads the source
/// byte and writes it back, so two steps at once could undo each other.
struct SpeakerControllerWakeSleepTests {
    let mock = MockSpeakerConnection()
    let log = MockKEFLog()
    let controller: SpeakerController

    init() {
        controller = SpeakerController(connection: mock, log: log.handler)
    }

    private static let ack = Data([0x52, 0x11, 0xFF])

    private static func reply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    @Test func wakeSetsStandbyThenPowersOnReadingTheNewByte() async throws {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .wifi)
        let afterStandby = off.with(standby: .never)
        mock.responses = [Self.reply(off), Self.ack, Self.reply(afterStandby), Self.ack]

        try await controller.macWoke(SpeakerSettings(powerOnInput: .optical), powerOn: true)

        #expect(mock.sentCommands == [
            KEFCommand.getSource(),
            KEFCommand.setSource(afterStandby.encode()),
            KEFCommand.getSource(),
            KEFCommand.setSource(afterStandby.with(isPoweredOn: true).with(input: .optical).encode()),
        ])
        #expect(log.messages(at: .info).first == "wake: standby, then power on")
    }

    @Test func wakeWithoutPowerOnOnlySetsStandby() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .wifi)
        mock.responses = [Self.reply(on), Self.ack]

        try await controller.macWoke(SpeakerSettings(), powerOn: false)

        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.setSource(on.with(standby: .never).encode())])
    }

    /// Sleep asks for 20 min, then powers off, which goes via 60 min.
    @Test func sleepSetsTwentyMinutesThenPowersOffViaSixty() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        let twenty = on.with(standby: .twentyMinutes)
        let sixty = on.with(standby: .sixtyMinutes)
        mock.responses = [Self.reply(on), Self.ack, Self.reply(twenty), Self.ack, Self.ack]

        try await controller.macSlept(SpeakerSettings(), powerOff: true)

        #expect(mock.sentCommands == [
            KEFCommand.getSource(),
            KEFCommand.setSource(twenty.encode()),
            KEFCommand.getSource(),
            KEFCommand.setSource(sixty.encode()),
            KEFCommand.setSource(sixty.with(isPoweredOn: false).encode()),
        ])
        #expect(log.messages(at: .info).first == "sleep: standby, then power off")
    }

    @Test func sleepWithoutPowerOffOnlySetsStandby() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .optical)
        mock.responses = [Self.reply(on), Self.ack]

        try await controller.macSlept(SpeakerSettings(), powerOff: false)

        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.setSource(on.with(standby: .twentyMinutes).encode())])
    }

    /// A failed standby write stops the sequence: the power step would
    /// fail on the same connection.
    @Test func aFailedStandbyStepStopsTheSequence() async throws {
        mock.errorToThrow = .connectionRefused
        await #expect(throws: KEFError.self) {
            try await controller.macWoke(SpeakerSettings(), powerOn: true)
        }
        #expect(mock.sentCommands.count == 1)
    }
}
