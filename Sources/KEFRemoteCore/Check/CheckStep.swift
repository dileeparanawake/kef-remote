import Foundation

/// One thing `kef-check` does to the speaker. Each goes through
/// ``SpeakerController``, so the check sends what the app sends.
public enum CheckAction: Equatable {
    case raiseVolume(by: Int)
    case lowerVolume(by: Int)
    case mute
    case unmute
    case powerOff
    case powerOn
    case setStandby(StandbyMode)
    case setInput(InputSource)
    /// Not built yet (another ticket adds it): the check says so and moves on.
    case swapLeftRight
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

    /// The inputs `--inputs` visits, in order.
    public static let inputsToVisit: [InputSource] = [.optical, .wifi, .bluetoothPaired, .aux, .usb]

    /// Every step, in order, for a speaker that starts as `start`.
    ///
    /// A speaker that starts off is turned on first, so the volume and
    /// standby steps run on a speaker that is on. Standby steps come after
    /// the power cycle, while it is on. Putting everything back is not a
    /// step: ``SpeakerCheck`` does that even when a step fails.
    public static func plan(from start: SpeakerStatus, includingInputs: Bool) -> [CheckStep] {
        var steps: [CheckStep] = []
        if !start.isPoweredOn {
            steps.append(CheckStep(name: "power on (it was off)", action: .powerOn))
        }
        steps += volumeAndMute(from: start.volume, on: nil)
        steps.append(CheckStep(name: "power off", action: .powerOff))
        steps.append(CheckStep(name: "power on", action: .powerOn))
        for mode in StandbyMode.allCases {
            steps.append(CheckStep(name: "standby \(mode.checkName)", action: .setStandby(mode)))
        }
        steps.append(CheckStep(name: "standby back to \(start.standby.checkName)", action: .setStandby(start.standby)))
        steps.append(CheckStep(name: "left/right swap", action: .swapLeftRight))
        if includingInputs {
            for input in inputsToVisit {
                steps.append(CheckStep(name: "input \(input.label)", action: .setInput(input)))
                steps += volumeAndMute(from: start.volume, on: input)
            }
            steps.append(CheckStep(name: "input back to \(start.input.label)", action: .setInput(start.input.codeToSelect)))
        }
        return steps
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
    /// state before. Nil when there is nothing to send yet.
    public func expectation(before: SpeakerStatus) -> CheckExpectation? {
        let volume = before.volume
        switch self {
        case .raiseVolume(let amount):
            return .volume(VolumeState(level: min(volume.level + amount, 100), isMuted: volume.isMuted))
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
        case .setStandby(let mode):
            return .standby(mode)
        case .setInput(let input):
            return .input(input)
        case .swapLeftRight:
            return nil
        }
    }

    /// Whether sending this to a speaker in `before` would leave it off
    /// with 20-minute standby, which crashes it. Power off is not one: the
    /// controller moves 20 to 60 minutes first.
    public func wouldLeaveTwentyMinutesWhileOff(before: SpeakerStatus) -> Bool {
        guard !before.isPoweredOn else { return false }
        switch self {
        case .setStandby(let mode):
            return mode == .twentyMinutes
        case .setInput:
            // The write keeps the standby time the speaker has.
            return before.standby == .twentyMinutes
        default:
            return false
        }
    }

    /// Power and input changes take the speaker a moment.
    var needsSettling: Bool {
        switch self {
        case .powerOn, .powerOff, .setInput: return true
        default: return false
        }
    }
}

/// What a step should read back.
public enum CheckExpectation: Equatable {
    case volume(VolumeState)
    /// Off, and never with 20-minute standby.
    case poweredOff
    case poweredOn
    case standby(StandbyMode)
    /// Bluetooth passes as either code: see ``compare(_:)``.
    case input(InputSource)

    /// Whether the read-back is the volume register, not the source byte.
    var readsVolume: Bool {
        if case .volume = self { return true }
        return false
    }

    /// Compare what the speaker read back with what was expected.
    public func compare(_ reading: CheckReading) -> CheckComparison {
        switch (self, reading) {
        case (.volume(let expected), .volume(let read)):
            return CheckComparison(
                passed: read == expected,
                detail: "expected \(expected.checkName), read \(read.checkName)"
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
    public let detail: String

    public init(passed: Bool, detail: String) {
        self.passed = passed
        self.detail = detail
    }
}

extension VolumeState {
    /// "42%" or "42% muted".
    var checkName: String { "\(level)%" + (isMuted ? " muted" : "") }
}

extension StandbyMode {
    /// "20 min", "60 min" or "never", to read inside a line.
    var checkName: String { label.lowercased() }
}
