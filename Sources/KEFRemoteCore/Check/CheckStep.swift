import Foundation

/// One thing `kef-check` does to the speaker. Each goes through
/// ``SpeakerController``, so the check sends what the app sends.
public enum CheckAction: Equatable {
    case raiseVolume(by: Int)
    /// Turn the speaker off and on, and press volume up the moment power
    /// reads on, when the LSX shows muted for a moment
    /// (``SpeakerCheck/pressAsPowerComesOn(_:before:since:)``).
    case raiseVolumeRightAfterPowerOn(by: Int)
    case lowerVolume(by: Int)
    case mute
    case unmute
    case powerOff
    /// Power on with Don't change: the speaker keeps its input and standby.
    case powerOn
    /// Power on the way the app does with an input chosen: power and
    /// input in one write (``SpeakerController/powerOn(applying:)``).
    case powerOnApplying(PowerOnInput)
    case setStandby(StandbyMode)
    case setInput(InputSource)
    case setLeftRightSwapped(Bool)
}

/// A named step of the check: send one action, read it back, compare.
public struct CheckStep: Equatable {
    public let name: String
    public let action: CheckAction

    public init(name: String, action: CheckAction) {
        self.name = name
        self.action = action
    }

    /// How far each volume step moves. Small, so it is barely heard.
    public static let volumeStep = 2

    /// The inputs `--inputs` visits: the Input menu's, in its order.
    public static let inputsToVisit: [InputSource] = PowerOnInput.allCases.compactMap(\.input)

    /// Every step, in order, for a speaker that starts as `start`.
    ///
    /// A speaker that starts off is turned on first: it ignores input,
    /// standby and left/right while off, so every other step runs with it
    /// on. After the first power cycle comes a volume press as power comes
    /// on. The second power cycle tests the power-on write with an input
    /// in it, then switches back. Putting everything back is not a step:
    /// ``SpeakerCheck`` does that even when a step fails, and turns a
    /// speaker that started off back off at the very end.
    public static func plan(from start: SpeakerStatus, includingInputs: Bool) -> [CheckStep] {
        var steps: [CheckStep] = []
        if !start.isPoweredOn {
            steps.append(CheckStep(name: "power on (it was off)", action: .powerOn))
        }
        steps += volumeAndMute(from: start.volume, on: nil)
        steps.append(CheckStep(name: "power off", action: .powerOff))
        steps.append(CheckStep(name: "power on", action: .powerOn))
        steps.append(CheckStep(
            name: "volume up right after power on", action: .raiseVolumeRightAfterPowerOn(by: volumeStep)
        ))
        let powerOnInput = powerOnInputToTry(from: start.input)
        steps.append(CheckStep(name: "power off again", action: .powerOff))
        steps.append(CheckStep(name: "power on to \(powerOnInput.label)", action: .powerOnApplying(powerOnInput)))
        steps.append(CheckStep(name: "input back to \(start.input.label)", action: .setInput(start.input.codeToSelect)))
        for mode in StandbyMode.allCases {
            steps.append(CheckStep(name: "standby \(mode.checkName)", action: .setStandby(mode)))
        }
        steps.append(CheckStep(name: "standby back to \(start.standby.checkName)", action: .setStandby(start.standby)))
        steps.append(CheckStep(name: "left/right swap", action: .setLeftRightSwapped(!start.isInversed)))
        steps.append(CheckStep(name: "left/right swap back", action: .setLeftRightSwapped(start.isInversed)))
        if includingInputs {
            for input in inputsToVisit {
                steps.append(CheckStep(name: "input \(input.label)", action: .setInput(input)))
                steps += volumeAndMute(from: start.volume, on: input)
            }
            steps.append(CheckStep(name: "input back to \(start.input.label)", action: .setInput(start.input.codeToSelect)))
        }
        return steps
    }

    /// The input the power-on step asks for: one the speaker isn't on, so
    /// the read-back shows whether the input in the power-on write took.
    /// Optical or Wi-Fi, which are always there to choose.
    static func powerOnInputToTry(from input: InputSource) -> PowerOnInput {
        input.isSameInput(as: .optical) ? .wifi : .optical
    }

    private static func volumeAndMute(from volume: VolumeState, on input: InputSource?) -> [CheckStep] {
        let suffix = input.map { " on \($0.label)" } ?? ""
        let up = CheckStep(name: "volume up" + suffix, action: .raiseVolume(by: volumeStep))
        let down = CheckStep(name: "volume down" + suffix, action: .lowerVolume(by: volumeStep))
        // Near the top, "up" stops at 100 and proves nothing: go down first.
        let volumeSteps = volume.level + volumeStep > 100 ? [down, up] : [up, down]
        return volumeSteps + [
            CheckStep(name: "mute" + suffix, action: .mute),
            CheckStep(name: "unmute" + suffix, action: .unmute),
        ]
    }
}

extension CheckAction {
    /// What the speaker should read back after this action, given its
    /// state before.
    public func expectation(before: SpeakerStatus) -> CheckExpectation {
        let volume = before.volume
        switch self {
        case .raiseVolume(let amount):
            return .volume(VolumeState(level: min(volume.level + amount, 100), isMuted: volume.isMuted))
        case .raiseVolumeRightAfterPowerOn:
            // The level moves as the speaker comes on: only the mute counts.
            return .muted(volume.isMuted)
        case .lowerVolume(let amount):
            return .volume(VolumeState(level: max(volume.level - amount, 0), isMuted: volume.isMuted))
        case .mute:
            return .volume(VolumeState(level: volume.level, isMuted: true))
        case .unmute:
            return .volume(VolumeState(level: volume.level, isMuted: false))
        case .powerOff:
            return .poweredOff
        case .powerOn:
            return .poweredOn
        case .powerOnApplying(let choice):
            return .poweredOnTo(choice.input ?? before.input)
        case .setStandby(let mode):
            return .standby(mode)
        case .setInput(let input):
            return .input(input)
        case .setLeftRightSwapped(let isSwapped):
            return .leftRightSwapped(isSwapped)
        }
    }

    /// Whether this is an input, standby or left/right write to a speaker
    /// that is off, which the check never sends. In the first real check
    /// (6 Oct 2026) every such write to a speaker that was off read back
    /// unchanged, so the speaker ignores them while off. And a write that
    /// leaves it off with 20-minute standby crashes it. Power off is not
    /// one: the controller moves 20 to 60 minutes first, while it is on.
    public func isIgnoredWhileOff(before: SpeakerStatus) -> Bool {
        guard !before.isPoweredOn else { return false }
        switch self {
        case .setStandby, .setInput, .setLeftRightSwapped: return true
        default: return false
        }
    }

    /// Turns the speaker on, after which its volume needs a moment.
    var turnsPowerOn: Bool {
        switch self {
        case .powerOn, .powerOnApplying: return true
        default: return false
        }
    }

    /// Turns the speaker on or off, which takes it a while.
    var changesPower: Bool {
        switch self {
        case .powerOn, .powerOff, .powerOnApplying: return true
        default: return false
        }
    }

    /// How long to keep reading back before the step fails.
    var readBackLimit: Duration {
        switch self {
        case .powerOn, .powerOff, .powerOnApplying: return SpeakerCheck.powerChangeLimit
        case .setStandby, .setInput, .setLeftRightSwapped: return SpeakerCheck.sourceWriteLimit
        case .raiseVolume, .raiseVolumeRightAfterPowerOn, .lowerVolume, .mute, .unmute: return .zero
        }
    }
}

/// What a step should read back.
public enum CheckExpectation: Equatable {
    case volume(VolumeState)
    /// Muted or not, whatever the level.
    case muted(Bool)
    /// Off, and never with 20-minute standby.
    case poweredOff
    case poweredOn
    /// On, and on this input.
    case poweredOnTo(InputSource)
    case standby(StandbyMode)
    /// Bluetooth passes as either code: see ``compare(_:)``.
    case input(InputSource)
    case leftRightSwapped(Bool)

    /// Whether the read-back is the volume register, not the source byte.
    var readsVolume: Bool {
        switch self {
        case .volume, .muted: return true
        default: return false
        }
    }

    /// Compare what the speaker read back with what was expected.
    public func compare(_ reading: CheckReading) -> CheckComparison {
        switch (self, reading) {
        case (.volume(let expected), .volume(let read)):
            return CheckComparison(
                passed: read == expected,
                detail: "expected \(expected.checkName), read \(read.checkName)"
            )
        case (.muted(let expected), .volume(let read)):
            return CheckComparison(
                passed: read.isMuted == expected,
                detail: "expected \(expected ? "muted" : "not muted"), read \(read.checkName)",
                why: read.isMuted && !expected
                    ? "a press as power came on kept a mute the speaker showed for a moment" : nil
            )
        case (.poweredOff, .source(let read)):
            if read.isPoweredOn {
                return CheckComparison(passed: false, detail: "expected off, read on")
            }
            if read.standby == .twentyMinutes {
                return CheckComparison(
                    passed: false,
                    detail: "expected off, read off with 20 min standby (that crashes the speaker)"
                )
            }
            return CheckComparison(passed: true, detail: "expected off, read off (standby \(read.standby.checkName))")
        case (.poweredOn, .source(let read)):
            return CheckComparison(passed: read.isPoweredOn, detail: "expected on, read \(read.isPoweredOn ? "on" : "off")")
        case (.poweredOnTo(let expected), .source(let read)):
            let wanted = "expected on to \(expected.label)"
            guard read.isPoweredOn else {
                return CheckComparison(passed: false, detail: "\(wanted), read off")
            }
            guard read.input.isSameInput(as: expected) else {
                return CheckComparison(
                    passed: false,
                    detail: "\(wanted), read on to \(read.input.label)",
                    why: "it powered on but kept \(read.input.label), so the input must be sent separately after power-on"
                )
            }
            return CheckComparison(passed: true, detail: "\(wanted), read on to \(read.input.label)")
        case (.standby(let expected), .source(let read)):
            return CheckComparison(
                passed: read.standby == expected,
                detail: "expected standby \(expected.checkName), read standby \(read.standby.checkName)"
            )
        case (.input(let expected), .source(let read)):
            // With nothing paired, the speaker reports Bluetooth as the
            // unpaired code whichever code selected it. Both mean Bluetooth.
            var detail = "expected \(expected.label), read \(read.input.label)"
            switch read.input {
            case .bluetoothPaired: detail += " (paired code 1001)"
            case .bluetoothUnpaired: detail += " (unpaired code 1111: nothing paired)"
            default: break
            }
            return CheckComparison(passed: read.input.isSameInput(as: expected), detail: detail)
        case (.leftRightSwapped(let expected), .source(let read)):
            return CheckComparison(
                passed: read.isInversed == expected,
                detail: "expected \(leftRightName(expected)), read \(leftRightName(read.isInversed))"
            )
        default:
            return CheckComparison(passed: false, detail: "read back the wrong register")
        }
    }
}

/// What the speaker read back after a step.
public enum CheckReading: Equatable {
    case volume(VolumeState)
    case source(SourceByte)
}

/// Whether a step's read-back matched, and what was expected and read.
public struct CheckComparison: Equatable {
    public let passed: Bool
    /// What was expected and read.
    public let detail: String
    /// What a failure means, shown after how long it waited.
    public let why: String?

    public init(passed: Bool, detail: String, why: String? = nil) {
        self.passed = passed
        self.detail = detail
        self.why = why
    }

    /// The detail, how long it waited (when given), then why.
    func line(waited: Duration?) -> String {
        var line = detail
        if let waited { line += " after \(SpeakerCheck.seconds(waited)) s" }
        if let why { line += ": \(why)" }
        return line
    }
}

/// "left/right swapped" or "left/right normal".
func leftRightName(_ isSwapped: Bool) -> String {
    "left/right \(isSwapped ? "swapped" : "normal")"
}

extension VolumeState {
    /// "42%" or "42% muted".
    var checkName: String { "\(level)%" + (isMuted ? " muted" : "") }
}

extension StandbyMode {
    /// "20 min", "60 min" or "never", to read inside a line.
    var checkName: String { label.lowercased() }
}
