import Testing
import Foundation
@testable import KEFRemoteCore

/// `applyStandby(_:for:)`: the chosen standby time, written when chosen,
/// on connect, on wake and at sleep, each with its reason in the log.
struct SpeakerControllerStandbyTests {
    let mock = MockSpeakerConnection()
    let log = MockKEFLog()
    let controller: SpeakerController

    init() {
        controller = SpeakerController(connection: mock, log: log.handler)
    }

    private static let ack = Data([0x52, 0x11, 0xFF])

    /// Queue a GET reply holding `source`, then an ack for one write.
    private func speakerReports(_ source: SourceByte) {
        mock.responses = [Data([0x52, 0x30, 0x81, source.encode(), 0x00]), Self.ack]
    }

    @Test func dontChangeSendsNothing() async throws {
        try await controller.applyStandby(SpeakerSettings(), for: .connect)
        #expect(mock.sentCommands.isEmpty)
        #expect(log.messages(at: .info).contains("standby: Don't change, leaving the speaker's (connect)"))
    }

    @Test func onConnectItWritesTheChosenTimeAndKeepsTheRest() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: true, standby: .never, input: .optical)
        speakerReports(on)
        try await controller.applyStandby(SpeakerSettings(standby: .sixtyMinutes), for: .connect)
        #expect(mock.sentCommands.count == 2)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(standby: .sixtyMinutes).encode()))
        #expect(log.messages(at: .info).contains("standby: never -> sixtyMinutes (connect)"))
    }

    @Test func aSpeakerAlreadyOnTheChosenTimeIsOnlyRead() async throws {
        speakerReports(SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi))
        try await controller.applyStandby(SpeakerSettings(standby: .sixtyMinutes), for: .chosen)
        #expect(mock.sentCommands.count == 1)
        #expect(log.messages(at: .info).contains("standby: already sixtyMinutes (chosen)"))
    }

    @Test func twentyMinutesIsWrittenToASpeakerThatIsOn() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        speakerReports(on)
        try await controller.applyStandby(SpeakerSettings(standby: .twentyMinutes), for: .chosen)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(standby: .twentyMinutes).encode()))
    }

    /// A write with the power bit off and 20 min standby is the one that
    /// crashes the speaker (see powerOff). The next power-on sets it.
    @Test func twentyMinutesIsNotWrittenToASpeakerThatIsOff() async throws {
        speakerReports(SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .wifi))
        try await controller.applyStandby(SpeakerSettings(standby: .twentyMinutes), for: .connect)
        #expect(mock.sentCommands.count == 1)
        #expect(log.messages(at: .info).contains(
            "standby: not writing twentyMinutes while the speaker is off (it crashes); the next power-on sets it (connect)"
        ))
    }

    @Test func wakeWithDontChangeWritesNever() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .wifi)
        speakerReports(on)
        try await controller.applyStandby(SpeakerSettings(), for: .wake)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(standby: .never).encode()))
        #expect(log.messages(at: .info).contains("standby: twentyMinutes -> never (wake)"))
    }

    @Test func sleepWritesTwentyMinutesEvenWhenNeverIsChosen() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        speakerReports(on)
        try await controller.applyStandby(SpeakerSettings(standby: .never), for: .sleep)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(standby: .twentyMinutes).encode()))
        #expect(log.messages(at: .info).contains("standby: never -> twentyMinutes (sleep)"))
    }

    // MARK: - Power on and off with a chosen time

    @Test func powerOnWritesTheChosenTimeInTheSameWrite() async throws {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .never, input: .wifi)
        speakerReports(off)
        try await controller.togglePower(applying: SpeakerSettings(standby: .twentyMinutes))
        #expect(mock.sentCommands.count == 2)
        let expected = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .wifi)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(expected.encode()))
    }

    /// Choosing 20 min doesn't remove the crash workaround: turning off
    /// still goes via 60 min first.
    @Test func chosenTwentyMinutesStillPowersOffViaSixty() async throws {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .twentyMinutes, input: .optical)
        mock.responses = [Data([0x52, 0x30, 0x81, on.encode(), 0x00]), Self.ack, Self.ack]
        let result = try await controller.togglePower(applying: SpeakerSettings(standby: .twentyMinutes))
        #expect(result == .turnedOff)
        #expect(mock.sentCommands.count == 3)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(standby: .sixtyMinutes).encode()))
        #expect(mock.sentCommands[2] == KEFCommand.setSource(
            on.with(standby: .sixtyMinutes).with(isPoweredOn: false).encode()
        ))
    }
}
