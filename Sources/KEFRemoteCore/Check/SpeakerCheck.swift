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
/// The real speaker is slow to power on and off, so after a power change
/// it reads back every second until it matches, says how long it took,
/// and rests before the next power change. Once power comes on, it waits
/// for the volume to settle before the next step.
///
/// Each line goes to `onLine` (the terminal) and to `log` (the log file).
public final class SpeakerCheck {
    // "The real speaker takes a while to power on and off; cycling it
    // quickly looks like failure because requests aren't taken. Needs
    // ~15-20 s between power on and power off." (Dileepa, after the first
    // real check on 6 Oct 2026, where power on still read off 2 s later.)

    /// How long to keep reading back after a power change before failing.
    public static let powerChangeLimit: Duration = .seconds(20)
    /// How long to wait after one power change lands before the next.
    public static let restBetweenPowerChanges: Duration = .seconds(15)
    /// How long to keep reading back an input, standby or left/right
    /// change. The speaker usually shows them at once; this is grace.
    public static let sourceWriteLimit: Duration = .seconds(5)
    /// How often to read back while waiting.
    public static let pollInterval: Duration = .seconds(1)

    // Second real check (6 Oct 2026): right as the LSX came on it read
    // 45% muted, and the volume moved under the next two steps (volume
    // down expected 45% muted, read 43% muted). kefctl, polling every
    // second, saw 45% unmuted all through power on, so it's brief.

    /// How long to wait for the volume to settle once power comes on.
    public static let volumeSettleLimit: Duration = .seconds(5)
    /// How far apart two volume reads are that must agree to call it settled.
    public static let volumeSettleInterval: Duration = .seconds(1)

    /// Why an input, standby or left/right step is not sent.
    static let notSentWhileOff = "not sent: the speaker is off, and it ignores input, standby and left/right while off"

    private let recorder: RecordingConnection
    private let controller: SpeakerController
    private let log: KEFLog
    private let clock: SpeakerClock
    private let onLine: (String) -> Void
    /// When the last power change landed (or was given up on).
    private var lastPowerChange: Duration?

    /// - Parameters:
    ///   - clock: Times the waits: ``RealSpeakerClock`` for the real
    ///     speaker, the simulated speaker's own clock otherwise.
    ///   - onLine: Gets each line to show, in order.
    public init(
        connection: SpeakerConnection,
        log: KEFLog,
        clock: SpeakerClock,
        onLine: @escaping (String) -> Void = { _ in }
    ) {
        let recorder = RecordingConnection(connection)
        self.recorder = recorder
        self.controller = SpeakerController(connection: recorder, log: log.write)
        self.log = log
        self.clock = clock
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
        if !start.isPoweredOn {
            show("The speaker is off. Turning it on first: it ignores input, standby and left/right "
                + "while off, so those are only sent while it's on. It goes off again at the end.", at: .info)
        }

        var results: [CheckStepResult] = []
        for step in CheckStep.plan(from: start, includingInputs: includingInputs) {
            var (result, answered) = await perform(step)
            results.append(result)
            show(result)
            if answered, result.verdict == .pass, step.action.turnsPowerOn {
                answered = await settleVolumeAfterPowerOn()
            }
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
            guard !step.action.isIgnoredWhileOff(before: before) else {
                return (CheckStepResult(name: step.name, verdict: .fail, detail: Self.notSentWhileOff), true)
            }
            let expectation = step.action.expectation(before: before)
            if step.action.changesPower { await restBeforePowerChange() }
            try await send(step.action)
            let (comparison, waited) = try await readBack(expectation, within: step.action.readBackLimit)
            if step.action.changesPower { lastPowerChange = clock.now }
            let showsWait = step.action.changesPower || waited > .zero
            let detail = comparison.line(waited: showsWait ? waited : nil)
            return (result(step.name, comparison.passed ? .pass : .fail, detail, since: mark), true)
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
        case .powerOnApplying(let choice): try await controller.powerOn(applying: SpeakerSettings(powerOnInput: choice))
        case .setStandby(let mode): try await controller.setStandby(mode)
        case .setInput(let input): try await controller.setInput(input)
        case .setLeftRightSwapped(let isSwapped): try await controller.setLeftRightSwapped(isSwapped)
        }
    }

    // MARK: - Waiting on the speaker

    /// Read back until the speaker shows what was expected, every
    /// ``pollInterval``, for up to `limit`. Returns the last comparison
    /// and how long it waited.
    private func readBack(_ expectation: CheckExpectation, within limit: Duration) async throws -> (CheckComparison, waited: Duration) {
        let started = clock.now
        while true {
            let reading: CheckReading = expectation.readsVolume
                ? .volume(try await controller.getVolumeState())
                : .source(try await controller.getSourceByte())
            let comparison = expectation.compare(reading)
            let waited = clock.now - started
            if comparison.passed || waited >= limit {
                return (comparison, waited)
            }
            await clock.sleep(for: Self.pollInterval)
        }
    }

    /// Read the volume every ``volumeSettleInterval`` until two reads in a
    /// row agree, for up to ``volumeSettleLimit``, and say which. Gives up
    /// waiting rather than failing: the next step reads it again anyway.
    @discardableResult
    private func settleVolume() async throws -> VolumeState {
        let started = clock.now
        var last = try await controller.getVolumeState()
        while clock.now - started < Self.volumeSettleLimit {
            await clock.sleep(for: Self.volumeSettleInterval)
            let next = try await controller.getVolumeState()
            if next == last {
                show("Volume settled at \(next.checkName) \(Self.seconds(clock.now - started)) s after power on", at: .info)
                return next
            }
            last = next
        }
        show("Volume still changing \(Self.seconds(Self.volumeSettleLimit)) s after power on "
            + "(last read \(last.checkName)); carrying on", at: .warning)
        return last
    }

    /// ``settleVolume()`` between steps. False when the speaker didn't
    /// answer, which stops the check.
    private func settleVolumeAfterPowerOn() async -> Bool {
        do {
            try await settleVolume()
            return true
        } catch {
            show("Volume could not be read after power on (\(error))", at: .error)
            return false
        }
    }

    /// Wait out what's left of ``restBetweenPowerChanges`` since the last one.
    private func restBeforePowerChange() async {
        guard let last = lastPowerChange else { return }
        let rest = last + Self.restBetweenPowerChanges - clock.now
        guard rest > .zero else { return }
        show("Waiting \(Self.seconds(rest)) s before the next power change", at: .info)
        await clock.sleep(for: rest)
    }

    /// Whole seconds, for the lines.
    static func seconds(_ duration: Duration) -> Int64 {
        duration.components.seconds
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

        // On first: the speaker ignores input, standby and left/right while off.
        problems += await attempt("power on") { [self] in
            guard try await !controller.getSourceByte().isPoweredOn else { return }
            try await changePower(to: .poweredOn) { try await self.controller.powerOn() }
        }
        problems += await attempt("input") { [self] in
            let now = try await controller.getState()
            guard !now.input.isSameInput(as: target.input) else { return }
            guard now.isPoweredOn else { throw CheckProblem(Self.notSentWhileOff) }
            try await controller.setInput(target.input.codeToSelect)
        }
        problems += await attempt("standby") { [self] in
            let now = try await controller.getState()
            guard now.standby != target.standby else { return }
            guard now.isPoweredOn else { throw CheckProblem(Self.notSentWhileOff) }
            try await controller.setStandby(target.standby)
        }
        problems += await attempt("left/right") { [self] in
            let now = try await controller.getState()
            guard now.isInversed != target.isInversed else { return }
            guard now.isPoweredOn else { throw CheckProblem(Self.notSentWhileOff) }
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
                try await changePower(to: .poweredOff) { try await self.controller.powerOff() }
            }
        }

        do {
            // The last input or standby write may take a moment to show.
            let started = clock.now
            var end = try await controller.getState()
            while !Self.differences(expected: target, read: end).isEmpty, clock.now - started < Self.sourceWriteLimit {
                await clock.sleep(for: Self.pollInterval)
                end = try await controller.getState()
            }
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

    /// Turn the speaker on or off while putting back: rest first, send,
    /// read back until it lands, and say how long it took.
    private func changePower(to expectation: CheckExpectation, _ send: () async throws -> Void) async throws {
        await restBeforePowerChange()
        try await send()
        let (comparison, waited) = try await readBack(expectation, within: Self.powerChangeLimit)
        lastPowerChange = clock.now
        let detail = comparison.line(waited: waited)
        show("put back: \(detail)", at: comparison.passed ? .info : .error)
        guard comparison.passed else { throw CheckProblem(detail) }
        // The volume is put back after this, so it must be the real one.
        if expectation == .poweredOn { try await settleVolume() }
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

    /// Why one part of putting back went wrong, in words.
    private struct CheckProblem: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
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
