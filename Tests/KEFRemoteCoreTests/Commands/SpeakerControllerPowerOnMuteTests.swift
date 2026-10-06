import Testing
import Foundation
@testable import KEFRemoteCore

/// Volume presses as the speaker powers on, against a speaker that reads
/// muted for a moment as it comes on (the LSX, second real check).
struct SpeakerControllerPowerOnMuteTests {
    let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .optical)
    let forty = VolumeState(level: 40, isMuted: false)

    private func speaker(_ volume: VolumeState, clock: SimulatedClock) -> SimulatedSpeaker {
        SimulatedSpeaker(
            volume: volume, source: off, clock: clock,
            powerChangeTime: .seconds(5), mutedAsItComesOnFor: .milliseconds(500)
        )
    }

    /// Power on, then wait until it lands: the muted moment.
    private func powerOnAndWait(_ controller: SpeakerController, _ clock: SimulatedClock) async throws {
        try await controller.powerOn()
        await clock.sleep(for: .seconds(5))
    }

    @Test func volumeUpAsItComesOnDoesNotKeepTheMomentaryMute() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(forty, clock: clock)
        let log = MockKEFLog()
        let controller = SpeakerController(connection: speaker, log: log.handler, clock: clock)

        try await powerOnAndWait(controller, clock)
        try await controller.raiseVolume(by: 5)

        #expect(speaker.volume == VolumeState(level: 45, isMuted: false))
        #expect(log.messages(at: .info).contains {
            $0.hasPrefix("raiseVolume: read muted 5 s after power on; reading again in 1 s")
        })
        #expect(log.messages(at: .info).contains("raiseVolume: read again: 40%, not muted (it was the power-on moment)"))
    }

    @Test func volumeDownAsItComesOnDoesNotKeepTheMomentaryMute() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(forty, clock: clock)
        let controller = SpeakerController(connection: speaker, clock: clock)

        try await powerOnAndWait(controller, clock)
        try await controller.lowerVolume(by: 5)

        #expect(speaker.volume == VolumeState(level: 35, isMuted: false))
    }

    /// Mute as it comes on mutes, rather than "unmuting" the moment.
    @Test func muteAsItComesOnMutes() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(forty, clock: clock)
        let controller = SpeakerController(connection: speaker, clock: clock)

        try await powerOnAndWait(controller, clock)
        try await controller.toggleMute()

        #expect(speaker.volume == VolumeState(level: 40, isMuted: true))
    }

    /// A speaker muted on purpose still reads muted the second time.
    @Test func aSpeakerMutedOnPurposeStaysMuted() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(VolumeState(level: 40, isMuted: true), clock: clock)
        let log = MockKEFLog()
        let controller = SpeakerController(connection: speaker, log: log.handler, clock: clock)

        try await powerOnAndWait(controller, clock)
        try await controller.raiseVolume(by: 5)

        #expect(speaker.volume == VolumeState(level: 45, isMuted: true))
        #expect(log.messages(at: .info).contains("raiseVolume: read again: 40% muted, still muted (keeping the mute)"))
    }

    @Test func aMutedPressLongAfterPowerOnIsNotReadAgain() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(VolumeState(level: 40, isMuted: true), clock: clock)
        let log = MockKEFLog()
        let controller = SpeakerController(connection: speaker, log: log.handler, clock: clock)

        try await powerOnAndWait(controller, clock)
        await clock.sleep(for: PowerOnMuteGuard.window)
        try await controller.raiseVolume(by: 5)

        #expect(speaker.volume == VolumeState(level: 45, isMuted: true))
        #expect(!log.messages(at: .info).contains { $0.contains("reading again") })
    }

    /// Turned on by something else (KEF's remote): the app sees it in a read.
    @Test func aReadThatShowsPowerJustCameOnStartsTheWindowToo() async throws {
        let clock = SimulatedClock()
        let speaker = speaker(forty, clock: clock)
        let controller = SpeakerController(connection: speaker, clock: clock)

        _ = try await controller.getSourceByte()
        _ = try await speaker.send(KEFCommand.setSource(off.with(isPoweredOn: true).encode()), expectResponseBytes: 3)
        await clock.sleep(for: .seconds(5))
        _ = try await controller.getSourceByte()
        try await controller.raiseVolume(by: 5)

        #expect(speaker.volume == VolumeState(level: 45, isMuted: false))
    }
}
