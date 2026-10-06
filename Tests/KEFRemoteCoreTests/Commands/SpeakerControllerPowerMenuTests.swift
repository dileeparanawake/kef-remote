import Testing
import Foundation
@testable import KEFRemoteCore

/// Turn speaker on / off in the menu does what its label says, against
/// the byte read at the click.
struct SpeakerControllerPowerMenuTests {
    let mock = MockSpeakerConnection()
    let log = MockKEFLog()

    private static let ack = Data([0x52, 0x11, 0xFF])

    private static func reply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    private let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    private let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .wifi)

    private var controller: SpeakerController { SpeakerController(connection: mock, log: log.handler) }

    @Test func turnOffPowersOffASpeakerThatIsOn() async throws {
        mock.responses = [Self.reply(on), Self.ack]

        let step = try await controller.runPowerMenuAction(.turnOff, applying: SpeakerSettings())

        #expect(step == .powerOff)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(isPoweredOn: false).encode()))
    }

    /// The power-off path keeps the crash workaround.
    @Test func turnOffSwitches20MinuteStandbyTo60First() async throws {
        let onTwenty = on.with(standby: .twentyMinutes)
        mock.responses = [Self.reply(onTwenty), Self.ack, Self.ack]

        _ = try await controller.runPowerMenuAction(.turnOff, applying: SpeakerSettings())

        #expect(mock.sentCommands[1] == KEFCommand.setSource(onTwenty.with(standby: .sixtyMinutes).encode()))
        #expect(mock.sentCommands[2] == KEFCommand.setSource(on.with(isPoweredOn: false).encode()))
    }

    @Test func turnOnAppliesTheTurnOnDefaults() async throws {
        mock.responses = [Self.reply(off), Self.ack]

        let step = try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings(powerOnInput: .optical))

        #expect(step == .powerOn)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(input: .optical).encode()))
    }

    @Test func turnOnSendsNothingToASpeakerAlreadyOn() async throws {
        mock.responses = [Self.reply(on)]

        let step = try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings(powerOnInput: .optical))

        #expect(step == .alreadyOn)
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("power menu: Turn speaker on, but the speaker is already on: nothing sent"))
    }

    @Test func turnOffSendsNothingToASpeakerAlreadyOff() async throws {
        mock.responses = [Self.reply(off)]

        let step = try await controller.runPowerMenuAction(.turnOff, applying: SpeakerSettings())

        #expect(step == .alreadyOff)
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("power menu: Turn speaker off, but the speaker is already off: nothing sent"))
    }

    @Test func toggleTurnsOnASpeakerThatIsOffWithTheDefaults() async throws {
        mock.responses = [Self.reply(off), Self.ack]

        let step = try await controller.runPowerMenuAction(.toggle, applying: SpeakerSettings(powerOnInput: .optical))

        #expect(step == .powerOn)
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(input: .optical).encode()))
    }
}
