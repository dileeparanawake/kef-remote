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

        #expect(step == .done(.powerOff))
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

        #expect(step == .done(.powerOn))
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(input: .optical).encode()))
    }

    @Test func turnOnSendsNothingToASpeakerAlreadyOn() async throws {
        mock.responses = [Self.reply(on)]

        let step = try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings(powerOnInput: .optical))

        #expect(step == .done(.alreadyOn))
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("power menu: Turn speaker on, but the speaker is already on: nothing sent"))
    }

    @Test func turnOffSendsNothingToASpeakerAlreadyOff() async throws {
        mock.responses = [Self.reply(off)]

        let step = try await controller.runPowerMenuAction(.turnOff, applying: SpeakerSettings())

        #expect(step == .done(.alreadyOff))
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains("power menu: Turn speaker off, but the speaker is already off: nothing sent"))
    }

    @Test func toggleTurnsOnASpeakerThatIsOffWithTheDefaults() async throws {
        mock.responses = [Self.reply(off), Self.ack]

        let step = try await controller.runPowerMenuAction(.toggle, applying: SpeakerSettings(powerOnInput: .optical))

        #expect(step == .done(.powerOn))
        #expect(mock.sentCommands[1] == KEFCommand.setSource(on.with(input: .optical).encode()))
    }

    // MARK: - Shares the power shortcut's guard (PowerToggleGuard)

    /// A click while the power shortcut's toggle is still going sends
    /// nothing: the two never write power at once.
    @Test func aClickWhileAShortcutToggleIsInFlightIsIgnored() async throws {
        let gated = GatedSpeakerConnection(responses: [Self.reply(on), Self.ack])
        let controller = SpeakerController(connection: gated, log: log.handler)

        let toggle = Task { try await controller.togglePower() }
        while gated.sentCommands.isEmpty { await Task.yield() }  // the toggle's read is in flight

        let step = try await controller.runPowerMenuAction(.turnOff, applying: SpeakerSettings())
        gated.open()

        #expect(step == .ignored(.inFlight))
        #expect(try await toggle.value == .turnedOff)
        #expect(gated.sentCommands.count == 2)  // the toggle's read and write only
        #expect(log.messages(at: .info).contains("power menu: Turn speaker off ignored, another power change is still going"))
    }

    /// The other way round: a shortcut press while a click is going.
    @Test func aShortcutWhileAClickIsInFlightIsIgnored() async throws {
        let gated = GatedSpeakerConnection(responses: [Self.reply(off), Self.ack])
        let controller = SpeakerController(connection: gated, log: log.handler)

        let click = Task { try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings()) }
        while gated.sentCommands.isEmpty { await Task.yield() }

        let toggled = try await controller.togglePower()
        gated.open()

        #expect(toggled == .ignored(.inFlight))
        #expect(try await click.value == .done(.powerOn))
        #expect(gated.sentCommands.count == 2)
    }

    @Test func aClickStraightAfterAShortcutToggleIsIgnored() async throws {
        let clock = SimulatedClock()
        let controller = SpeakerController(connection: mock, log: log.handler, clock: clock)
        mock.responses = [Self.reply(on), Self.ack]

        _ = try await controller.togglePower()
        await clock.sleep(for: .milliseconds(300))
        let step = try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings())

        #expect(step == .ignored(.tooSoon(sinceLast: .milliseconds(300))))
        #expect(mock.sentCommands.count == 2)
    }

    /// A click that found the speaker already that way still counts: it
    /// read the speaker, so a press straight after it waits the gap.
    @Test func aShortcutStraightAfterAClickThatSentNothingIsIgnored() async throws {
        let clock = SimulatedClock()
        let controller = SpeakerController(connection: mock, log: log.handler, clock: clock)
        mock.responses = [Self.reply(on)]

        #expect(try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings()) == .done(.alreadyOn))
        await clock.sleep(for: .milliseconds(500))

        #expect(try await controller.togglePower() == .ignored(.tooSoon(sinceLast: .milliseconds(500))))
        #expect(mock.sentCommands.count == 1)
    }

    @Test func aClickAfterTheGapGoes() async throws {
        let clock = SimulatedClock()
        let controller = SpeakerController(connection: mock, log: log.handler, clock: clock)
        mock.responses = [Self.reply(on), Self.ack, Self.reply(off), Self.ack]

        _ = try await controller.togglePower()
        await clock.sleep(for: PowerToggleGuard.minimumGap)

        #expect(try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings()) == .done(.powerOn))
    }

    /// A click that fails still ends, so the next press isn't stuck.
    @Test func aFailedClickDoesNotBlockTheNextToggle() async throws {
        let clock = SimulatedClock()
        let controller = SpeakerController(connection: mock, log: log.handler, clock: clock)
        mock.failures = [.connectionRefused]
        mock.responses = [Self.reply(off), Self.ack]

        await #expect(throws: KEFError.self) {
            try await controller.runPowerMenuAction(.turnOn, applying: SpeakerSettings())
        }
        await clock.sleep(for: PowerToggleGuard.minimumGap)

        #expect(try await controller.togglePower() == .turnedOn)
    }
}
