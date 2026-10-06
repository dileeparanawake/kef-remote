import Testing
import Foundation
@testable import KEFRemoteCore

struct SimulatedSpeakerTests {
    let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)

    @Test func answersAReadWithWhatItHolds() async throws {
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: on)
        let controller = SpeakerController(connection: speaker)

        let state = try await controller.getState()

        #expect(state.volume == VolumeState(level: 40, isMuted: false))
        #expect(state.isPoweredOn)
        #expect(state.input == .wifi)
        #expect(state.standby == .sixtyMinutes)
    }

    @Test func keepsWhatItIsSent() async throws {
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: on)
        let controller = SpeakerController(connection: speaker)

        try await controller.raiseVolume(by: 2)
        try await controller.mute()
        try await controller.setInput(.aux)

        #expect(speaker.volume == VolumeState(level: 42, isMuted: true))
        #expect(speaker.source.input == .aux)
    }

    @Test func reportsBluetoothAsUnpairedWhenNothingIsPaired() async throws {
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: on)
        try await SpeakerController(connection: speaker).setInput(.bluetoothPaired)
        #expect(speaker.source.input == .bluetoothUnpaired)
    }

    @Test func reportsBluetoothAsPairedWhenADeviceIsPaired() async throws {
        let speaker = SimulatedSpeaker(
            volume: VolumeState(level: 40, isMuted: false), source: on, hasPairedBluetooth: true
        )
        try await SpeakerController(connection: speaker).setInput(.bluetoothPaired)
        #expect(speaker.source.input == .bluetoothPaired)
    }

    @Test func crashesWhenTurnedOffWithTwentyMinuteStandby() async throws {
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: on)
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
        let twenty = on.with(standby: .twentyMinutes)
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: twenty)

        try await SpeakerController(connection: speaker).powerOff()

        #expect(!speaker.hasCrashed)
        #expect(!speaker.source.isPoweredOn)
        #expect(speaker.source.standby == .sixtyMinutes)
    }

    @Test func turnsDownACommandItDoesNotKnow() async throws {
        let speaker = SimulatedSpeaker(volume: VolumeState(level: 40, isMuted: false), source: on)
        await #expect(throws: KEFError.invalidResponse) {
            _ = try await speaker.send(Data([0x00, 0x01]), expectResponseBytes: 5)
        }
    }
}
