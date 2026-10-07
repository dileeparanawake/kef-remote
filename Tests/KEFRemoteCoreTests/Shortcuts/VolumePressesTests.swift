import Testing
@testable import KEFRemoteCore

/// Volume presses that come while one is waiting for the speaker add up
/// into one write, so a burst of presses is never a burst of writes.
struct VolumePressesTests {
    static let step = 5

    private func presses(_ commands: VolumeCommand...) -> VolumePresses {
        var presses = VolumePresses()
        for command in commands { presses.add(command, step: Self.step) }
        return presses
    }

    @Test func threeUpsAddUpToFifteen() {
        let ups = presses(.up, .up, .up)
        #expect(ups.count == 3)
        #expect(ups.applied(to: VolumeState(level: 45, isMuted: false)) == VolumeState(level: 60, isMuted: false))
    }

    @Test func upAndDownCancel() {
        let pair = presses(.up, .down)
        #expect(pair.applied(to: VolumeState(level: 45, isMuted: false)) == VolumeState(level: 45, isMuted: false))
    }

    @Test func theSumIsClampedOnce() {
        #expect(presses(.up, .up, .up).applied(to: VolumeState(level: 95, isMuted: false)).level == 100)
        #expect(presses(.down, .down).applied(to: VolumeState(level: 5, isMuted: false)).level == 0)
    }

    @Test func twoMutePressesLeaveTheMuteAsItWas() {
        let pair = presses(.mute, .mute)
        #expect(!pair.flipsMute)
        #expect(pair.applied(to: VolumeState(level: 45, isMuted: true)) == VolumeState(level: 45, isMuted: true))
    }

    @Test func threeMutePressesFlipIt() {
        #expect(presses(.mute, .mute, .mute).applied(to: VolumeState(level: 45, isMuted: false))
            == VolumeState(level: 45, isMuted: true))
    }

    @Test func volumeKeysKeepTheMute() {
        #expect(presses(.up).applied(to: VolumeState(level: 45, isMuted: true)) == VolumeState(level: 50, isMuted: true))
    }

    @Test func oneUpLogsAsItAlwaysDid() {
        #expect(presses(.up).name == "volume up")
    }

    @Test func aBurstLogsHowManyWereCombined() {
        #expect(presses(.up, .up, .mute).name == "3 presses combined (volume up ×2, mute ×1)")
    }

    /// The HUD shows Muted / Unmuted only when every press was mute.
    @Test func theHUDShowsMuteOnlyForMutePresses() {
        #expect(presses(.mute, .mute).hudCommand == .mute)
        #expect(presses(.up, .mute).hudCommand == .up)
        #expect(presses(.down).hudCommand == .down)
    }
}
