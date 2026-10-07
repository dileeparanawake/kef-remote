import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerCheckTests {
    let wifiOn = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    let forty = VolumeState(level: 40, isMuted: false)

    /// Runs the check and keeps every line it shows. Pass the speaker's
    /// clock when its timing matters.
    private func run(
        _ connection: SpeakerConnection, includingInputs: Bool = false, model: SpeakerModel = .other,
        log: KEFLog = MockKEFLog(), clock: SpeakerClock = SimulatedClock()
    ) async -> (report: CheckReport, lines: [String]) {
        var lines: [String] = []
        let check = SpeakerCheck(connection: connection, log: log, clock: clock, onLine: { lines.append($0) })
        let report = await check.run(includingInputs: includingInputs, model: model)
        return (report, lines)
    }

    private func verdict(of name: String, in report: CheckReport) -> CheckStepResult.Verdict? {
        report.steps.first { $0.name == name }?.verdict
    }

    private func detail(of name: String, in report: CheckReport) -> String? {
        report.steps.first { $0.name == name }?.detail
    }

    // MARK: - A working speaker

    @Test func everyStepPassesOnAWorkingSpeaker() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)

        let (report, _) = await run(speaker)

        #expect(report.passed)
        #expect(report.steps.filter { $0.verdict == .fail }.isEmpty)
        #expect(report.restore?.verdict == .pass)
        #expect(speaker.volume == forty)
        #expect(speaker.source == wifiOn)
    }

    @Test func swapsLeftAndRightThenBack() async {
        let (report, lines) = await run(SimulatedSpeaker(volume: forty, source: wifiOn))
        #expect(verdict(of: "left/right swap", in: report) == .pass)
        #expect(verdict(of: "left/right swap back", in: report) == .pass)
        #expect(lines.contains(
            "PASS  left/right swap: expected left/right swapped, read left/right swapped [sent 53 30 81 52, read 52 30 81 52 00]"
        ))
    }

    @Test func putsTheSwapBackAfterAFailure() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)
        let faulty = FaultySpeaker(speaker)
        var failedOnce = false
        // The speaker stops answering just as the swap is undone.
        faulty.failsSend = { data in
            guard !failedOnce, speaker.source.isInversed, data == KEFCommand.setSource(wifiOn.encode()) else { return false }
            failedOnce = true
            return true
        }

        let (report, _) = await run(faulty)

        #expect(verdict(of: "left/right swap back", in: report) == .fail)
        #expect(report.restore?.verdict == .pass)
        #expect(speaker.source == wifiOn)
    }

    @Test func withInputsVisitsEachInputAndPutsTheStartingOneBack() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)

        let (report, _) = await run(speaker, includingInputs: true)

        #expect(report.passed)
        #expect(verdict(of: "mute on USB", in: report) == .pass)
        let bluetooth = report.steps.first { $0.name == "input Bluetooth" }
        #expect(bluetooth?.verdict == .pass)
        #expect(bluetooth?.detail.contains("unpaired code 1111") == true)
        #expect(speaker.source.input == .wifi)
    }

    /// The second real check asked an LSX for USB, and it stayed on Aux.
    @Test func withInputsOnAnLSXLeavesOutUSB() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn, hasUSBInput: false)

        let (report, _) = await run(speaker, includingInputs: true, model: .lsx)

        #expect(report.passed)
        #expect(verdict(of: "input Aux", in: report) == .pass)
        #expect(verdict(of: "input USB", in: report) == nil)
    }

    @Test func aSpeakerThatStartsOffEndsOff() async {
        let off = wifiOn.with(isPoweredOn: false)
        let speaker = SimulatedSpeaker(volume: forty, source: off)

        let (report, _) = await run(speaker)

        #expect(report.passed)
        #expect(speaker.source == off)
    }

    // MARK: - A speaker that is slow to power on and off

    /// Like the real one: 7 s to power on or off, and a quick second
    /// power change isn't taken.
    private func slowSpeaker(_ source: SourceByte, clock: SimulatedClock, keepsInputOnPowerOn: Bool = false) -> SimulatedSpeaker {
        SimulatedSpeaker(
            volume: forty, source: source, keepsInputOnPowerOn: keepsInputOnPowerOn, clock: clock,
            powerChangeTime: .seconds(7), ignoresPowerChangesFor: .seconds(12)
        )
    }

    @Test func waitsForEachPowerChangeAndSaysHowLongItTook() async {
        let clock = SimulatedClock()
        let speaker = slowSpeaker(wifiOn, clock: clock)

        let (report, lines) = await run(speaker, clock: clock)

        #expect(report.passed)
        #expect(detail(of: "power off", in: report) == "expected off, read off (standby 60 min) after 7 s")
        #expect(detail(of: "power on", in: report) == "expected on, read on after 7 s")
        #expect(lines.contains("Waiting 15 s before the next power change"))
        #expect(speaker.source == wifiOn)
    }

    @Test func givesUpOnAPowerChangeAfterTwentySeconds() async {
        let clock = SimulatedClock()
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn, clock: clock, powerChangeTime: .seconds(30))

        let (report, _) = await run(speaker, clock: clock)

        #expect(!report.passed)
        #expect(verdict(of: "power off", in: report) == .fail)
        #expect(detail(of: "power off", in: report) == "expected off, read on after 20 s")
        #expect(!speaker.hasCrashed)
    }

    @Test func aSpeakerThatStartsOffIsTurnedOnFirstAndOffLast() async {
        let clock = SimulatedClock()
        let off = wifiOn.with(isPoweredOn: false)
        let speaker = slowSpeaker(off, clock: clock)

        let (report, lines) = await run(speaker, includingInputs: true, clock: clock)

        #expect(report.passed)
        #expect(report.steps.first?.name == "power on (it was off)")
        #expect(report.steps.first?.detail == "expected on, read on after 7 s")
        #expect(lines.contains { $0.hasPrefix("The speaker is off. Turning it on first") })
        #expect(lines.contains("put back: expected off, read off (standby 60 min) after 7 s"))
        #expect(speaker.source == off)
    }

    // MARK: - Letting the volume settle after power on

    /// Like the LSX in the second real check: muted for a moment as it
    /// comes on.
    private func speakerThatFlashesMuted(_ source: SourceByte, clock: SimulatedClock) -> SimulatedSpeaker {
        SimulatedSpeaker(
            volume: forty, source: source, clock: clock,
            powerChangeTime: .seconds(7), ignoresPowerChangesFor: .seconds(12),
            mutedAsItComesOnFor: .milliseconds(500)
        )
    }

    @Test func waitsForTheVolumeToSettleAfterPowerOnBeforeTheVolumeSteps() async {
        let clock = SimulatedClock()
        let speaker = speakerThatFlashesMuted(wifiOn.with(isPoweredOn: false), clock: clock)

        let (report, lines) = await run(speaker, clock: clock)

        // Read muted at 7 s, then 40% at 8 s and 9 s: two reads agree.
        #expect(lines.contains("Volume settled at 40% 2 s after power on"))
        // Expected from the settled read, not the muted moment.
        #expect(detail(of: "volume up", in: report) == "expected 42%, read 42%")
        #expect(report.passed)
        #expect(speaker.volume == forty)
    }

    @Test func saysWhenTheVolumeIsStillChangingAndCarriesOn() async {
        let clock = SimulatedClock()
        let speaker = slowSpeaker(wifiOn.with(isPoweredOn: false), clock: clock)
        let faulty = FaultySpeaker(speaker)
        // For 10 s after it comes on, every volume read says something new.
        var reads = 0
        faulty.volumeRead = {
            guard speaker.source.isPoweredOn, clock.now < .seconds(17) else { return nil }
            reads += 1
            return VolumeState(level: 40 + reads, isMuted: false)
        }

        let (report, lines) = await run(faulty, clock: clock)

        #expect(lines.contains { $0.hasPrefix("Volume still changing 5 s after power on (last read") })
        #expect(report.steps.first?.verdict == .pass)
    }

    // MARK: - Volume up right as power comes on

    @Test func volumeUpRightAfterPowerOnEndsUnmutedAndSaysWhatThePressRead() async {
        let clock = SimulatedClock()
        let speaker = speakerThatFlashesMuted(wifiOn, clock: clock)

        let (report, _) = await run(speaker, clock: clock)

        let name = "volume up right after power on"
        #expect(verdict(of: name, in: report) == .pass)
        #expect(detail(of: name, in: report) == "expected not muted, read 42% once settled; "
            + "the press read 40% muted, then 40% 1 s later (the speaker showed muted as it came on)")
        // The volume goes back after the step.
        #expect(report.passed)
        #expect(speaker.volume == forty)
    }

    @Test func volumeUpRightAfterPowerOnSaysWhenNoMuteWasSeen() async {
        let clock = SimulatedClock()
        let speaker = slowSpeaker(wifiOn, clock: clock)

        let (report, _) = await run(speaker, clock: clock)

        #expect(detail(of: "volume up right after power on", in: report)
            == "expected not muted, read 42% once settled; the press read 40%")
    }

    @Test func volumeUpRightAfterPowerOnFailsWhenThePressKeepsTheMute() async {
        let clock = SimulatedClock()
        let speaker = slowSpeaker(wifiOn, clock: clock)
        let faulty = FaultySpeaker(speaker)
        // Reads muted for 3 s as this step's power on lands (the second
        // time it comes on): longer than the press waits to read again.
        var wasOn = true
        var timesOn = 0
        var stepCameOnAt: Duration?
        faulty.failsSend = { _ in
            let isOn = speaker.source.isPoweredOn
            if isOn && !wasOn {
                timesOn += 1
                if timesOn == 2 { stepCameOnAt = clock.now }
            }
            wasOn = isOn
            return false
        }
        faulty.volumeRead = {
            guard let stepCameOnAt, clock.now < stepCameOnAt + .seconds(3) else { return nil }
            return VolumeState(level: speaker.volume.level, isMuted: true)
        }

        let (report, _) = await run(faulty, clock: clock)

        let name = "volume up right after power on"
        #expect(verdict(of: name, in: report) == .fail)
        #expect(detail(of: name, in: report)?.contains("a press as power came on kept a mute") == true)
        // Put back unmuted, as it started.
        #expect(speaker.volume == forty)
    }

    @Test func neverSendsInputStandbyOrSwapWhileTheSpeakerIsOff() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)
        let faulty = FaultySpeaker(speaker)
        // Power on is acknowledged but never happens.
        faulty.ignoresWrite = { $0.isPowerOnWrite && !speaker.source.isPoweredOn }
        var writesWhileOff: [Data] = []
        faulty.failsSend = { data in
            // A write to a speaker that is off, not turning it on, that
            // changes anything but power.
            let current = speaker.source
            if data.isSourceWrite, !data.isPowerOnWrite, !current.isPoweredOn,
               SourceByte(byte: data[3]).with(isPoweredOn: false) != current {
                writesWhileOff.append(data)
            }
            return false
        }

        let (report, _) = await run(faulty, includingInputs: true)

        #expect(writesWhileOff.isEmpty)
        #expect(!speaker.hasCrashed)
        #expect(verdict(of: "power on", in: report) == .fail)
        #expect(detail(of: "standby 20 min", in: report) == SpeakerCheck.notSentWhileOff)
        #expect(detail(of: "input Aux", in: report) == SpeakerCheck.notSentWhileOff)
        #expect(report.restore?.verdict == .fail)
    }

    // MARK: - Power on with an input (the v0.3.0 write)

    @Test func powerOnWithAnInputPassesWhenTheInputTakes() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)

        let (report, _) = await run(speaker)

        #expect(verdict(of: "power on to Optical", in: report) == .pass)
        #expect(detail(of: "power on to Optical", in: report) == "expected on to Optical, read on to Optical after 0 s")
        #expect(verdict(of: "input back to Wi-Fi", in: report) == .pass)
        #expect(speaker.source == wifiOn)
    }

    @Test func powerOnThatKeepsTheOldInputFailsAndSaysSo() async {
        let clock = SimulatedClock()
        let speaker = slowSpeaker(wifiOn, clock: clock, keepsInputOnPowerOn: true)

        let (report, _) = await run(speaker, clock: clock)

        #expect(verdict(of: "power on to Optical", in: report) == .fail)
        #expect(detail(of: "power on to Optical", in: report)
            == "expected on to Optical, read on to Wi-Fi after 20 s: it powered on but kept Wi-Fi, "
            + "so the input must be sent separately after power-on")
        // The rest carries on, and the start goes back.
        #expect(verdict(of: "standby never", in: report) == .pass)
        #expect(report.restore?.verdict == .pass)
        #expect(speaker.source == wifiOn)
    }

    @Test func neverLeavesTwentyMinutesOnASpeakerThatIsOff() async {
        let offWithTwenty = wifiOn.with(isPoweredOn: false).with(standby: .twentyMinutes)
        let speaker = SimulatedSpeaker(volume: forty, source: offWithTwenty)

        let (report, _) = await run(speaker, includingInputs: true)

        #expect(!speaker.hasCrashed)
        #expect(report.passed)
        // Off with 20 min can't be put back: it ends off with 60, and says why.
        #expect(speaker.source == offWithTwenty.with(standby: .sixtyMinutes))
        #expect(report.restore?.detail.contains("60 min, not 20") == true)
    }

    @Test func putsTwentyMinutesBackOnASpeakerThatIsOn() async {
        let onWithTwenty = wifiOn.with(standby: .twentyMinutes)
        let speaker = SimulatedSpeaker(volume: forty, source: onWithTwenty)

        let (report, _) = await run(speaker)

        #expect(report.passed)
        #expect(!speaker.hasCrashed)
        #expect(speaker.source == onWithTwenty)
    }

    @Test func putsAMutedStartBack() async {
        let mutedThirty = VolumeState(level: 30, isMuted: true)
        let speaker = SimulatedSpeaker(volume: mutedThirty, source: wifiOn)

        let (report, _) = await run(speaker, includingInputs: true)

        #expect(report.passed)
        #expect(speaker.volume == mutedThirty)
    }

    // MARK: - Failures

    @Test func aWrongReadBackFailsThatStepAndCarriesOn() async {
        let faulty = FaultySpeaker(SimulatedSpeaker(volume: forty, source: wifiOn))
        faulty.ignoresWrite = { $0.isMutingVolumeWrite }

        let (report, lines) = await run(faulty)

        #expect(!report.passed)
        #expect(verdict(of: "mute", in: report) == .fail)
        #expect(lines.contains { $0.hasPrefix("FAIL  mute: expected 40% muted, read 40%") })
        // The steps after it still ran.
        #expect(verdict(of: "standby never", in: report) == .pass)
        #expect(report.restore?.verdict == .pass)
    }

    @Test func aFailedExchangeStopsTheStepsAndStillPutsTheStartBack() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)
        let faulty = FaultySpeaker(speaker)
        var failedOnce = false
        // The speaker stops answering just as it is turned back on.
        faulty.failsSend = { data in
            guard !failedOnce, data.isPowerOnWrite, !speaker.source.isPoweredOn else { return false }
            failedOnce = true
            return true
        }

        let (report, lines) = await run(faulty)

        #expect(!report.passed)
        #expect(verdict(of: "power on", in: report) == .fail)
        #expect(verdict(of: "standby 20 min", in: report) == nil)
        #expect(lines.contains("Stopping: the speaker didn't answer. Putting the starting state back."))
        #expect(report.restore?.verdict == .pass)
        #expect(speaker.source == wifiOn)
        #expect(speaker.volume == forty)
    }

    @Test func aSpeakerThatCannotBeReadIsLeftAlone() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .commandTimeout

        let (report, _) = await run(mock)

        #expect(!report.passed)
        #expect(report.steps.map(\.name) == ["read starting state"])
        #expect(report.restore == nil)
        // Only the one read went out: nothing was written.
        #expect(mock.sentCommands == [KEFCommand.getVolume()])
    }

    // MARK: - Output

    @Test func showsTheStartEachStepThePutBackAndASummary() async {
        let (report, lines) = await run(SimulatedSpeaker(volume: forty, source: wifiOn))

        #expect(lines.first == "Start: volume 40%, power on, input Wi-Fi, standby 60 min, left/right normal")
        #expect(lines.contains("PASS  volume up: expected 42%, read 42% [sent 53 25 81 2A, read 52 25 81 2A 00]"))
        #expect(lines.contains { $0.hasPrefix("PASS  put back: volume 40%, power on, input Wi-Fi, standby 60 min, left/right normal") })
        #expect(lines.last == "Done: 16 passed, 0 failed. Starting state put back.")
        #expect(report.summary == lines.last)
    }

    @Test func logsEachLineFailuresAsErrors() async {
        let log = MockKEFLog()
        let faulty = FaultySpeaker(SimulatedSpeaker(volume: forty, source: wifiOn))
        faulty.ignoresWrite = { $0.isMutingVolumeWrite }

        _ = await run(faulty, log: log)

        #expect(log.messages(at: .info).contains { $0.hasPrefix("PASS  volume up") })
        #expect(log.messages(at: .error).contains { $0.hasPrefix("FAIL  mute") })
        // The controller's bytes land in the same log.
        #expect(log.messages(at: .debug).contains("SEND: 47 25 80"))
    }
}
