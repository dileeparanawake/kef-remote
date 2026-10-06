import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerCheckTests {
    let wifiOn = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .wifi)
    let forty = VolumeState(level: 40, isMuted: false)

    /// Runs the check and keeps every line it shows.
    private func run(
        _ connection: SpeakerConnection, includingInputs: Bool = false, log: KEFLog = MockKEFLog()
    ) async -> (report: CheckReport, lines: [String]) {
        var lines: [String] = []
        let check = SpeakerCheck(connection: connection, log: log, onLine: { lines.append($0) })
        let report = await check.run(includingInputs: includingInputs)
        return (report, lines)
    }

    private func verdict(of name: String, in report: CheckReport) -> CheckStepResult.Verdict? {
        report.steps.first { $0.name == name }?.verdict
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

    @Test func swapIsSkippedUntilItIsBuilt() async {
        let (report, _) = await run(SimulatedSpeaker(volume: forty, source: wifiOn))
        let swap = report.steps.first { $0.name == "left/right swap" }
        #expect(swap?.verdict == .skip)
        #expect(swap?.detail == "not built yet (another ticket adds it)")
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

    @Test func aSpeakerThatStartsOffEndsOff() async {
        let off = wifiOn.with(isPoweredOn: false)
        let speaker = SimulatedSpeaker(volume: forty, source: off)

        let (report, _) = await run(speaker)

        #expect(report.passed)
        #expect(speaker.source == off)
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

    @Test func doesNotWriteTwentyMinutesWhenTheSpeakerStaysOff() async {
        let speaker = SimulatedSpeaker(volume: forty, source: wifiOn)
        let faulty = FaultySpeaker(speaker)
        // Power on is acknowledged but never happens.
        faulty.ignoresWrite = { $0.isPowerOnWrite && !speaker.source.isPoweredOn }

        let (report, _) = await run(faulty)

        #expect(!speaker.hasCrashed)
        #expect(verdict(of: "power on", in: report) == .fail)
        let twenty = report.steps.first { $0.name == "standby 20 min" }
        #expect(twenty?.verdict == .fail)
        #expect(twenty?.detail == "not sent: the speaker is off, and 20 min standby while off crashes it")
        #expect(report.restore?.verdict == .fail)
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

        #expect(lines.first == "Start: volume 40%, power on, input Wi-Fi, standby 60 min")
        #expect(lines.contains("PASS  volume up: expected 42%, read 42% [sent 53 25 81 2A, read 52 25 81 2A 00]"))
        #expect(lines.contains { $0.hasPrefix("PASS  put back: volume 40%, power on, input Wi-Fi, standby 60 min") })
        #expect(lines.last == "Done: 10 passed, 0 failed, 1 skipped. Starting state put back.")
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
