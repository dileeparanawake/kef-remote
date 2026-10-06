import Testing
import Foundation
@testable import KEFRemoteCore

/// Input ▸ switches, then reads back whether the speaker took it.
struct SpeakerControllerInputSwitchTests {
    let onAux = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .aux)
    let forty = VolumeState(level: 40, isMuted: false)

    private func controller(_ speaker: SimulatedSpeaker, clock: SimulatedClock, log: MockKEFLog = MockKEFLog()) -> SpeakerController {
        SpeakerController(connection: speaker, log: log.handler, clock: clock)
    }

    @Test func aSwitchTheSpeakerTakesSaysSo() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: forty, source: onAux, clock: clock)

        let result = try await controller(speaker, clock: clock).switchInput(to: .optical)

        #expect(result == .switched(.optical))
        #expect(speaker.source.input == .optical)
    }

    /// The second real check: an LSX asked for USB stayed on Aux.
    @Test func aSwitchTheSpeakerDoesNotTakeSaysWhereItStayed() async throws {
        let clock = SimulatedClock()
        let log = MockKEFLog()
        // Replies take no time, so the clock shows only the read-back's waits.
        let speaker = SimulatedSpeaker(volume: forty, source: onAux, hasUSBInput: false, clock: clock, replyTime: .zero)

        let result = try await controller(speaker, clock: clock, log: log).switchInput(to: .usb)

        #expect(result == .notTaken(asked: .usb, stayedOn: .aux))
        #expect(clock.now == SpeakerController.inputReadBackLimit)
        #expect(log.messages(at: .warning).contains(
            "switchInput: asked for USB, the speaker stayed on Aux after 2 s (it may not have that input)"
        ))
    }

    @Test func bluetoothWithNothingPairedCountsAsTaken() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: forty, source: onAux, clock: clock)

        let result = try await controller(speaker, clock: clock).switchInput(to: .bluetoothPaired)

        #expect(result == .switched(.bluetoothUnpaired))
    }

    /// It ignores input writes while off (first real check), so none is sent.
    @Test func aSpeakerThatIsOffIsNotSentTheSwitch() async throws {
        let mock = MockSpeakerConnection()
        mock.responses = [Data([0x52, 0x30, 0x81, onAux.with(isPoweredOn: false).encode(), 0x00])]
        let log = MockKEFLog()

        let result = try await SpeakerController(connection: mock, log: log.handler).switchInput(to: .optical)

        #expect(result == .speakerOff)
        #expect(mock.sentCommands == [KEFCommand.getSource()])
        #expect(log.messages(at: .info).contains(
            "switchInput: Optical not sent: the speaker is off, and it ignores input while off"
        ))
    }
}
