import Foundation

/// Runs every speaker command and reads each one back: what
/// `make speaker-check` does, so an agent can check the speaker end to
/// end without Dileepa.
///
/// It reads the starting state, runs the steps in ``CheckStep/plan(from:includingInputs:)``
/// through ``SpeakerController`` (so the 20-minute standby workaround
/// applies), then puts the starting state back, even after a failure.
/// A wrong read-back fails that step and the check carries on; an
/// exchange that gets no answer stops the steps and goes straight to
/// putting things back.
///
/// Each line goes to `onLine` (the terminal) and to `log` (the log file).
public final class SpeakerCheck {
    /// The wait after a power or input change on the real speaker, before
    /// reading it back.
    public static let standardSettle: @Sendable () async -> Void = {
        try? await Task.sleep(for: .seconds(2))
    }

    /// Why a step that would leave 20-minute standby on a speaker that is
    /// off is not sent.
    static let notSentWhileOff = "not sent: the speaker is off, and 20 min standby while off crashes it"

    private let recorder: RecordingConnection
    private let controller: SpeakerController
    private let log: KEFLog
    private let settle: () async -> Void
    private let onLine: (String) -> Void

    /// - Parameters:
    ///   - settle: Waits after power and input changes (none in tests).
    ///   - onLine: Gets each line to show, in order.
    public init(
        connection: SpeakerConnection,
        log: KEFLog,
        settle: @escaping () async -> Void = {},
        onLine: @escaping (String) -> Void = { _ in }
    ) {
        let recorder = RecordingConnection(connection)
        self.recorder = recorder
        self.controller = SpeakerController(connection: recorder, log: log.write)
        self.log = log
        self.settle = settle
        self.onLine = onLine
    }

    /// Run the check. With `includingInputs`, also switch to each input
    /// and repeat the volume and mute steps there.
    public func run(includingInputs: Bool) async -> CheckReport {
        let start: SpeakerStatus
        do {
            start = try await controller.getState()
        } catch {
            let result = CheckStepResult(
                name: "read starting state", verdict: .fail,
                detail: "no answer (\(error)); nothing was changed"
            )
            show(result)
            return finish(CheckReport(steps: [result], restore: nil))
        }
        show("Start: \(Self.describe(start))", at: .info)

        var results: [CheckStepResult] = []
        for step in CheckStep.plan(from: start, includingInputs: includingInputs) {
            let (result, answered) = await perform(step)
            results.append(result)
            show(result)
            if !answered {
                show("Stopping: the speaker didn't answer. Putting the starting state back.", at: .warning)
                break
            }
        }

        let restore = await putBack(start)
        show(restore)
        return finish(CheckReport(steps: results, restore: restore))
    }

    // MARK: - Steps

    /// Send one step and read it back. `answered` is false when an
    /// exchange failed, which stops the check.
    private func perform(_ step: CheckStep) async -> (result: CheckStepResult, answered: Bool) {
        let mark = recorder.mark
        do {
            let before = try await controller.getState()
            guard !step.action.wouldLeaveTwentyMinutesWhileOff(before: before) else {
                return (CheckStepResult(name: step.name, verdict: .fail, detail: Self.notSentWhileOff), true)
            }
            let expectation = step.action.expectation(before: before)
            try await send(step.action)
            if step.action.needsSettling { await settle() }
            let reading: CheckReading = expectation.readsVolume
                ? .volume(try await controller.getVolumeState())
                : .source(try await controller.getSourceByte())
            let comparison = expectation.compare(reading)
            return (result(step.name, comparison.passed ? .pass : .fail, comparison.detail, since: mark), true)
        } catch {
            return (result(step.name, .fail, "no answer (\(error))", since: mark), false)
        }
    }

    private func send(_ action: CheckAction) async throws {
        switch action {
        case .raiseVolume(let amount): try await controller.raiseVolume(by: amount)
        case .lowerVolume(let amount): try await controller.lowerVolume(by: amount)
        case .mute: try await controller.mute()
        case .unmute: try await controller.unmute()
        case .powerOff: try await controller.powerOff()
        // Don't change: the speaker keeps the input and standby it has.
        case .powerOn: try await controller.powerOn()
        case .setStandby(let mode): try await controller.setStandby(mode)
        case .setInput(let input): try await controller.setInput(input)
        case .setLeftRightSwapped(let isSwapped): try await controller.setLeftRightSwapped(isSwapped)
        }
    }

    // MARK: - Putting the starting state back

    /// The state the check leaves the speaker in: the one it started in,
    /// except a speaker that started off with 20-minute standby ends on
    /// 60 minutes, since power off moves it there to avoid the crash.
    public static func stateToPutBack(from start: SpeakerStatus) -> SpeakerStatus {
        guard !start.isPoweredOn, start.standby == .twentyMinutes else { return start }
        return SpeakerStatus(
            volume: start.volume, isPoweredOn: false, isInversed: start.isInversed,
            input: start.input, standby: .sixtyMinutes
        )
    }

    /// Each way `read` differs from `expected`, in words. Both Bluetooth
    /// codes count as the same input.
    public static func differences(expected: SpeakerStatus, read: SpeakerStatus) -> [String] {
        var differences: [String] = []
        if read.volume != expected.volume {
            differences.append("volume \(expected.volume.checkName), read \(read.volume.checkName)")
        }
        if read.isPoweredOn != expected.isPoweredOn {
            differences.append("power \(onOff(expected.isPoweredOn)), read \(onOff(read.isPoweredOn))")
        }
        if !read.input.isSameInput(as: expected.input) {
            differences.append("input \(expected.input.label), read \(read.input.label)")
        }
        if read.standby != expected.standby {
            differences.append("standby \(expected.standby.checkName), read standby \(read.standby.checkName)")
        }
        if read.isInversed != expected.isInversed {
            differences.append("\(leftRightName(expected.isInversed)), read \(leftRightName(read.isInversed))")
        }
        return differences
    }

    /// `volume 40%, power on, input Wi-Fi, standby 60 min, left/right normal`
    static func describe(_ status: SpeakerStatus) -> String {
        "volume \(status.volume.checkName), power \(onOff(status.isPoweredOn)), "
            + "input \(status.input.label), standby \(status.standby.checkName), "
            + leftRightName(status.isInversed)
    }

    private static func onOff(_ isOn: Bool) -> String { isOn ? "on" : "off" }

    /// Put each part back on its own, so one that fails doesn't stop the
    /// rest, then read the speaker and compare.
    private func putBack(_ start: SpeakerStatus) async -> CheckStepResult {
        let target = Self.stateToPutBack(from: start)
        log.info("put back: \(Self.describe(target))")
        let mark = recorder.mark
        var problems: [String] = []

        // On first, so the input and standby writes never meet a speaker
        // that is off.
        problems += await attempt("power on") { [self] in
            guard try await !controller.getSourceByte().isPoweredOn else { return }
            try await controller.powerOn()
            await settle()
        }
        problems += await attempt("input") { [self] in
            let now = try await controller.getState()
            guard !now.input.isSameInput(as: target.input) else { return }
            let action = CheckAction.setInput(target.input.codeToSelect)
            guard !action.wouldLeaveTwentyMinutesWhileOff(before: now) else { throw NotSentWhileOff() }
            try await controller.setInput(target.input.codeToSelect)
            await settle()
        }
        problems += await attempt("standby") { [self] in
            let now = try await controller.getState()
            guard now.standby != target.standby else { return }
            let action = CheckAction.setStandby(target.standby)
            guard !action.wouldLeaveTwentyMinutesWhileOff(before: now) else { throw NotSentWhileOff() }
            try await controller.setStandby(target.standby)
        }
        problems += await attempt("left/right") { [self] in
            let now = try await controller.getState()
            guard now.isInversed != target.isInversed else { return }
            let action = CheckAction.setLeftRightSwapped(target.isInversed)
            guard !action.wouldLeaveTwentyMinutesWhileOff(before: now) else { throw NotSentWhileOff() }
            try await controller.setLeftRightSwapped(target.isInversed)
        }
        problems += await attempt("volume") { [self] in
            let now = try await controller.getVolumeState()
            guard now != target.volume else { return }
            if target.volume.isMuted {
                // Mute first, then move the level: raise and lower keep the
                // mute, so the level is never heard on the way.
                try await controller.mute()
                let change = target.volume.level - now.level
                if change > 0 { try await controller.raiseVolume(by: change) }
                if change < 0 { try await controller.lowerVolume(by: -change) }
            } else {
                try await controller.setVolume(target.volume.level)
            }
        }
        if !target.isPoweredOn {
            // Last, through the controller, so 20 min becomes 60 first.
            problems += await attempt("power off") { [self] in
                try await controller.powerOff()
                await settle()
            }
        }

        do {
            let end = try await controller.getState()
            problems = Self.differences(expected: target, read: end) + problems
        } catch {
            problems.append("could not read it back (\(error))")
        }

        guard problems.isEmpty else {
            return result("put back", .fail, "expected \(Self.describe(target)); " + problems.joined(separator: "; "), since: mark)
        }
        var detail = Self.describe(target)
        if target.standby != start.standby {
            detail += " (standby 60 min, not 20: 20 min can't be left on a speaker that is off)"
        }
        return result("put back", .pass, detail, since: mark)
    }

    /// Run one part of putting back. Returns what went wrong, if anything.
    private func attempt(_ what: String, _ body: () async throws -> Void) async -> [String] {
        do {
            try await body()
            return []
        } catch {
            log.error("put back: \(what) failed (\(error))")
            return ["\(what) failed (\(error))"]
        }
    }

    private struct NotSentWhileOff: Error, CustomStringConvertible {
        var description: String { SpeakerCheck.notSentWhileOff }
    }

    // MARK: - Output

    private func result(_ name: String, _ verdict: CheckStepResult.Verdict, _ detail: String, since mark: Int) -> CheckStepResult {
        CheckStepResult(
            name: name, verdict: verdict, detail: detail,
            sentBytes: recorder.lastWrite(since: mark),
            readBytes: recorder.lastReadReply(since: mark)
        )
    }

    private func show(_ result: CheckStepResult) {
        show(result.line, at: result.verdict == .fail ? .error : .info)
    }

    private func show(_ line: String, at level: KEFLogLevel) {
        onLine(line)
        log.write(level, line)
    }

    private func finish(_ report: CheckReport) -> CheckReport {
        show(report.summary, at: report.passed ? .info : .error)
        return report
    }
}
