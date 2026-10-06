import Testing
import Foundation
@testable import KEFRemoteCore

struct CheckStepTests {
    let start = SpeakerStatus(
        volume: VolumeState(level: 40, isMuted: false),
        isPoweredOn: true, isInversed: false, input: .wifi, standby: .sixtyMinutes
    )

    private func status(
        level: Int = 40, isMuted: Bool = false, isPoweredOn: Bool = true,
        input: InputSource = .wifi, standby: StandbyMode = .sixtyMinutes
    ) -> SpeakerStatus {
        SpeakerStatus(
            volume: VolumeState(level: level, isMuted: isMuted),
            isPoweredOn: isPoweredOn, isInversed: false, input: input, standby: standby
        )
    }

    // MARK: - The plan

    @Test func runsEverySpeakerCommandInOrder() {
        let plan = CheckStep.plan(from: start, includingInputs: false)
        #expect(plan.map(\.name) == [
            "volume up", "volume down", "mute", "unmute",
            "power off", "power on",
            "standby 20 min", "standby 60 min", "standby never", "standby back to 60 min",
            "left/right swap",
        ])
        #expect(plan.map(\.action) == [
            .raiseVolume(by: 2), .lowerVolume(by: 2), .mute, .unmute,
            .powerOff, .powerOn,
            .setStandby(.twentyMinutes), .setStandby(.sixtyMinutes), .setStandby(.never),
            .setStandby(.sixtyMinutes),
            .swapLeftRight,
        ])
    }

    @Test func turnsTheSpeakerOnFirstWhenItStartsOff() {
        let plan = CheckStep.plan(from: status(isPoweredOn: false), includingInputs: false)
        #expect(plan.first == CheckStep(name: "power on (it was off)", action: .powerOn))
    }

    @Test func goesDownFirstNearTheTopSoBothStepsMove() {
        let plan = CheckStep.plan(from: status(level: 99), includingInputs: false)
        #expect(plan.prefix(2).map(\.action) == [.lowerVolume(by: 2), .raiseVolume(by: 2)])
    }

    @Test func withInputsVisitsEachOneThenGoesBack() {
        let plan = CheckStep.plan(from: status(input: .bluetoothUnpaired), includingInputs: true)
        let inputSteps = plan.filter { if case .setInput = $0.action { return true }; return false }
        #expect(inputSteps.map(\.name) == [
            "input Optical", "input Wi-Fi", "input Bluetooth", "input Aux", "input USB",
            "input back to Bluetooth",
        ])
        // Bluetooth is chosen with the paired code, even to go back to it.
        #expect(inputSteps.map(\.action) == [
            .setInput(.optical), .setInput(.wifi), .setInput(.bluetoothPaired), .setInput(.aux),
            .setInput(.usb), .setInput(.bluetoothPaired),
        ])
    }

    @Test func repeatsVolumeAndMuteOnEachInput() {
        let plan = CheckStep.plan(from: start, includingInputs: true)
        let afterOptical = plan.drop { $0.name != "input Optical" }.dropFirst().prefix(4)
        #expect(afterOptical.map(\.name) == [
            "volume up on Optical", "volume down on Optical", "mute on Optical", "unmute on Optical",
        ])
    }

    @Test func leavesInputsAloneWithoutTheFlag() {
        let plan = CheckStep.plan(from: start, includingInputs: false)
        #expect(!plan.contains { if case .setInput = $0.action { return true }; return false })
    }

    // MARK: - What each step should read back

    @Test func volumeUpAndDownKeepTheMuteAndStopAtTheEnds() {
        #expect(CheckAction.raiseVolume(by: 2).expectation(before: status(level: 40, isMuted: true))
            == .volume(VolumeState(level: 42, isMuted: true)))
        #expect(CheckAction.raiseVolume(by: 2).expectation(before: status(level: 99))
            == .volume(VolumeState(level: 100, isMuted: false)))
        #expect(CheckAction.lowerVolume(by: 2).expectation(before: status(level: 1))
            == .volume(VolumeState(level: 0, isMuted: false)))
    }

    @Test func muteAndUnmuteKeepTheLevel() {
        #expect(CheckAction.mute.expectation(before: status(level: 30))
            == .volume(VolumeState(level: 30, isMuted: true)))
        #expect(CheckAction.unmute.expectation(before: status(level: 30, isMuted: true))
            == .volume(VolumeState(level: 30, isMuted: false)))
    }

    @Test func sourceStepsExpectWhatTheySet() {
        #expect(CheckAction.powerOff.expectation(before: start) == .poweredOff)
        #expect(CheckAction.powerOn.expectation(before: start) == .poweredOn)
        #expect(CheckAction.setStandby(.never).expectation(before: start) == .standby(.never))
        #expect(CheckAction.setInput(.aux).expectation(before: start) == .input(.aux))
        // Not built yet: nothing to send or read back.
        #expect(CheckAction.swapLeftRight.expectation(before: start) == nil)
    }

    // MARK: - Comparing

    @Test func aMatchingReadPasses() {
        let comparison = CheckExpectation.volume(VolumeState(level: 42, isMuted: false))
            .compare(.volume(VolumeState(level: 42, isMuted: false)))
        #expect(comparison == CheckComparison(passed: true, detail: "expected 42%, read 42%"))
    }

    @Test func aWrongReadFails() {
        let comparison = CheckExpectation.volume(VolumeState(level: 42, isMuted: true))
            .compare(.volume(VolumeState(level: 42, isMuted: false)))
        #expect(comparison == CheckComparison(passed: false, detail: "expected 42% muted, read 42%"))
    }

    @Test func bluetoothPassesAsPairedOrUnpairedAndSaysWhich() {
        let expectation = CheckExpectation.input(.bluetoothPaired)
        let unpaired = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .bluetoothUnpaired)
        let paired = unpaired.with(input: .bluetoothPaired)

        #expect(expectation.compare(.source(unpaired)) == CheckComparison(
            passed: true, detail: "expected Bluetooth, read Bluetooth (unpaired code 1111: nothing paired)"
        ))
        #expect(expectation.compare(.source(paired)) == CheckComparison(
            passed: true, detail: "expected Bluetooth, read Bluetooth (paired code 1001)"
        ))
        #expect(!expectation.compare(.source(paired.with(input: .aux))).passed)
    }

    @Test func offWithTwentyMinuteStandbyFails() {
        let off = SourceByte(isPoweredOn: false, isInversed: false, standby: .sixtyMinutes, input: .wifi)
        #expect(CheckExpectation.poweredOff.compare(.source(off))
            == CheckComparison(passed: true, detail: "expected off, read off (standby 60 min)"))
        #expect(CheckExpectation.poweredOff.compare(.source(off.with(standby: .twentyMinutes)))
            == CheckComparison(passed: false, detail: "expected off, read off with 20 min standby (that crashes the speaker)"))
    }

    @Test func standbyAndPowerSayWhatTheyRead() {
        let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .never, input: .wifi)
        #expect(CheckExpectation.poweredOn.compare(.source(on))
            == CheckComparison(passed: true, detail: "expected on, read on"))
        #expect(CheckExpectation.standby(.twentyMinutes).compare(.source(on))
            == CheckComparison(passed: false, detail: "expected standby 20 min, read standby never"))
    }

    // MARK: - Never 20 min while off

    @Test func refusesToWriteTwentyMinutesToASpeakerThatIsOff() {
        #expect(CheckAction.setStandby(.twentyMinutes).wouldLeaveTwentyMinutesWhileOff(before: status(isPoweredOn: false)))
        #expect(!CheckAction.setStandby(.twentyMinutes).wouldLeaveTwentyMinutesWhileOff(before: status()))
        // Moving off 20 min while off is safe; any other write keeps 20 min.
        let offWithTwenty = status(isPoweredOn: false, standby: .twentyMinutes)
        #expect(!CheckAction.setStandby(.sixtyMinutes).wouldLeaveTwentyMinutesWhileOff(before: offWithTwenty))
        #expect(CheckAction.setInput(.aux).wouldLeaveTwentyMinutesWhileOff(before: offWithTwenty))
        // Power off has its own workaround in the controller.
        #expect(!CheckAction.powerOff.wouldLeaveTwentyMinutesWhileOff(before: status(standby: .twentyMinutes)))
    }

    @Test func aSpeakerThatStartedOffWithTwentyMinutesEndsOnSixty() {
        let offWithTwenty = status(isPoweredOn: false, standby: .twentyMinutes)
        #expect(SpeakerCheck.stateToPutBack(from: offWithTwenty).standby == .sixtyMinutes)
        #expect(SpeakerCheck.stateToPutBack(from: status(standby: .twentyMinutes)).standby == .twentyMinutes)
    }

    @Test func putBackComparesBluetoothCodesAsOneInput() {
        let started = status(input: .bluetoothUnpaired)
        #expect(SpeakerCheck.differences(expected: started, read: status(input: .bluetoothPaired)).isEmpty)
        #expect(SpeakerCheck.differences(expected: started, read: status(level: 38, input: .aux))
            == ["volume 40%, read 38%", "input Bluetooth, read Aux"])
    }

    // MARK: - Lines

    @Test func aLineShowsTheVerdictTheReadAndTheBytes() {
        let result = CheckStepResult(
            name: "volume up", verdict: .pass, detail: "expected 42%, read 42%",
            sentBytes: Data([0x53, 0x25, 0x81, 0x2A]), readBytes: Data([0x52, 0x25, 0x81, 0x2A, 0x00])
        )
        #expect(result.line == "PASS  volume up: expected 42%, read 42% [sent 53 25 81 2A, read 52 25 81 2A 00]")
    }

    @Test func aLineSaysWhenNothingWasSent() {
        let result = CheckStepResult(
            name: "mute", verdict: .pass, detail: "expected 42% muted, read 42% muted",
            sentBytes: nil, readBytes: Data([0x52, 0x25, 0x81, 0xAA, 0x00])
        )
        #expect(result.line.hasSuffix("[sent nothing, read 52 25 81 AA 00]"))
    }

    @Test func aSkippedLineHasNoBytes() {
        let result = CheckStepResult(name: "left/right swap", verdict: .skip, detail: "not built yet")
        #expect(result.line == "SKIP  left/right swap: not built yet")
    }
}
