import Testing
import Foundation
@testable import KEFRemoteCore

struct SimulatedSpeakerTests {
    let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    let forty = VolumeState(level: 40, isMuted: false)

    @Test func answersAReadWithWhatItHolds() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        let controller = SpeakerController(connection: speaker)

        let state = try await controller.getState()

        #expect(state.volume == forty)
        #expect(state.isPoweredOn)
        #expect(state.input == .wifi)
        #expect(state.standby == .sixtyMinutes)
    }

    @Test func keepsWhatItIsSent() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        let controller = SpeakerController(connection: speaker)

        try await controller.raiseVolume(by: 2)
        try await controller.mute()
        try await controller.setInput(.aux)

        #expect(speaker.volume == VolumeState(level: 42, isMuted: true))
        #expect(speaker.source.input == .aux)
    }

    @Test func reportsBluetoothAsUnpairedWhenNothingIsPaired() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        try await SpeakerController(connection: speaker).setInput(.bluetoothPaired)
        #expect(speaker.source.input == .bluetoothUnpaired)
    }

    @Test func reportsBluetoothAsPairedWhenADeviceIsPaired() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on, hasPairedBluetooth: true)
        try await SpeakerController(connection: speaker).setInput(.bluetoothPaired)
        #expect(speaker.source.input == .bluetoothPaired)
    }

    @Test func crashesWhenTurnedOffWithTwentyMinuteStandby() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        let offWithTwenty = on.with(isPoweredOn: false).with(standby: .twentyMinutes)

        await #expect(throws: KEFError.self) {
            _ = try await speaker.send(KEFCommand.setSource(offWithTwenty.encode()), expectResponseBytes: 3)
        }
        #expect(speaker.hasCrashed)
        // A crashed speaker stops answering.
        await #expect(throws: KEFError.self) {
            _ = try await speaker.send(KEFCommand.getVolume(), expectResponseBytes: 5)
        }
    }

    @Test func survivesThePowerOffWorkaround() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on.with(standby: .twentyMinutes))

        try await SpeakerController(connection: speaker).powerOff()

        #expect(!speaker.hasCrashed)
        #expect(!speaker.source.isPoweredOn)
        #expect(speaker.source.standby == .sixtyMinutes)
    }

    @Test func turnsDownACommandItDoesNotKnow() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await speaker.send(Data([0x00, 0x01]), expectResponseBytes: 5)
        }
    }

    // MARK: - Off, and taking time to power on and off

    @Test func ignoresInputStandbyAndSwapWhileOff() async throws {
        let off = on.with(isPoweredOn: false)
        let speaker = SimulatedSpeaker(volume: forty, source: off)
        let controller = SpeakerController(connection: speaker)

        try await controller.setInput(.aux)
        try await controller.setStandby(.never)
        try await controller.setLeftRightSwapped(true)

        #expect(speaker.source == off)
    }

    @Test func takesVolumeAndMuteWhileOff() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on.with(isPoweredOn: false))
        let controller = SpeakerController(connection: speaker)

        try await controller.raiseVolume(by: 2)
        try await controller.mute()

        #expect(speaker.volume == VolumeState(level: 42, isMuted: true))
    }

    @Test func powerOnLandsAfterThePowerChangeTime() async throws {
        let clock = SimulatedClock()
        let off = on.with(isPoweredOn: false)
        let speaker = SimulatedSpeaker(volume: forty, source: off, clock: clock, powerChangeTime: .seconds(7))
        let controller = SpeakerController(connection: speaker)

        try await controller.powerOn()
        // Still reads off while it boots, as the real speaker did.
        await clock.sleep(for: .seconds(6))
        #expect(try await !controller.getSourceByte().isPoweredOn)

        await clock.sleep(for: .seconds(1))
        #expect(try await controller.getSourceByte().isPoweredOn)
    }

    @Test func ignoresSourceWritesWhileBooting() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(
            volume: forty, source: on.with(isPoweredOn: false), clock: clock, powerChangeTime: .seconds(7)
        )
        let controller = SpeakerController(connection: speaker)

        try await controller.powerOn()
        await clock.sleep(for: .seconds(3))
        try await controller.setInput(.aux)
        await clock.sleep(for: .seconds(4))

        #expect(speaker.source == on)
    }

    @Test func ignoresAPowerChangeTooSoonAfterTheLastOne() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(
            volume: forty, source: on, clock: clock,
            powerChangeTime: .seconds(5), ignoresPowerChangesFor: .seconds(15)
        )
        let controller = SpeakerController(connection: speaker)

        try await controller.powerOff()
        await clock.sleep(for: .seconds(5))
        #expect(!speaker.source.isPoweredOn)

        // 10 s after it went off: not taken.
        await clock.sleep(for: .seconds(10))
        try await controller.powerOn()
        await clock.sleep(for: .seconds(5))
        #expect(!speaker.source.isPoweredOn)

        // 15 s after: taken.
        try await controller.powerOn()
        await clock.sleep(for: .seconds(5))
        #expect(speaker.source.isPoweredOn)
    }

    @Test func powerOnTakesTheInputInTheSameWrite() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on.with(isPoweredOn: false))
        try await SpeakerController(connection: speaker).powerOn(applying: SpeakerSettings(powerOnInput: .optical))
        #expect(speaker.source.input == .optical)
    }

    @Test func canKeepTheOldInputOnPowerOn() async throws {
        let speaker = SimulatedSpeaker(
            volume: forty, source: on.with(isPoweredOn: false), keepsInputOnPowerOn: true
        )
        try await SpeakerController(connection: speaker).powerOn(applying: SpeakerSettings(powerOnInput: .optical))
        #expect(speaker.source.isPoweredOn)
        #expect(speaker.source.input == .wifi)
    }

    // MARK: - Muted for a moment as it comes on

    /// Like the LSX in the second real check (6 Oct 2026): it read muted
    /// right as power came on, though it wasn't muted before or after.
    private func speakerThatFlashesMuted(_ clock: SimulatedClock) -> SimulatedSpeaker {
        SimulatedSpeaker(
            volume: forty, source: on.with(isPoweredOn: false), clock: clock,
            powerChangeTime: .seconds(7), mutedAsItComesOnFor: .milliseconds(500)
        )
    }

    /// The volume as the speaker answers a read, with no controller in
    /// between (the controller reads again in that moment).
    private func readVolume(_ speaker: SimulatedSpeaker) async throws -> VolumeState {
        let reply = try await speaker.send(KEFCommand.getVolume(), expectResponseBytes: 5)
        return VolumeCoding.decode(reply[3])
    }

    @Test func readsMutedForAMomentAsItComesOn() async throws {
        let clock = SimulatedClock()
        let speaker = speakerThatFlashesMuted(clock)

        try await SpeakerController(connection: speaker).powerOn()
        await clock.sleep(for: .seconds(7))
        #expect(try await readVolume(speaker) == VolumeState(level: 40, isMuted: true))

        await clock.sleep(for: .milliseconds(500))
        #expect(try await readVolume(speaker) == forty)
    }

    @Test func aMutedVolumeWrittenInThatMomentStaysMuted() async throws {
        let clock = SimulatedClock()
        let speaker = speakerThatFlashesMuted(clock)

        try await SpeakerController(connection: speaker).powerOn()
        await clock.sleep(for: .seconds(7))
        _ = try await speaker.send(KEFCommand.setVolume(VolumeCoding.encode(level: 42, isMuted: true)), expectResponseBytes: 3)
        await clock.sleep(for: .seconds(1))

        #expect(speaker.volume == VolumeState(level: 42, isMuted: true))
    }

    @Test func doesNotReadMutedWhenItWasAlreadyOn() async throws {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: forty, source: on, clock: clock, mutedAsItComesOnFor: .seconds(1))
        #expect(try await readVolume(speaker) == forty)
    }

    // MARK: - No USB input (the LSX)

    @Test func aSpeakerWithNoUSBStaysOnItsInputWhenAskedForUSB() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on.with(input: .aux), hasUSBInput: false)
        let controller = SpeakerController(connection: speaker)

        try await controller.setInput(.usb)

        #expect(speaker.source.input == .aux)
        try await controller.setInput(.optical)
        #expect(speaker.source.input == .optical)
    }

    @Test func aSpeakerWithUSBSwitchesToIt() async throws {
        let speaker = SimulatedSpeaker(volume: forty, source: on)
        try await SpeakerController(connection: speaker).setInput(.usb)
        #expect(speaker.source.input == .usb)
    }

    // MARK: - Clock

    @Test func simulatedClockMovesOnlyWhenSlept() async {
        let clock = SimulatedClock()
        #expect(clock.now == .zero)
        await clock.sleep(for: .seconds(3))
        await clock.sleep(for: .milliseconds(500))
        #expect(clock.now == .milliseconds(3500))
    }
}
