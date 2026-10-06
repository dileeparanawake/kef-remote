/// What the app sets on the speaker, chosen in Settings. Saved in
/// config.json under `"speakerSettings"`. Every choice starts at Don't
/// change, so a new install leaves the speaker as its owner set it.
public struct SpeakerSettings: Codable, Equatable, Sendable {
    /// The input the speaker switches to when the app turns it on.
    public var powerOnInput: PowerOnInput
    /// How long the speaker waits with no sound before it goes to standby.
    public var standby: StandbyChoice

    public init(powerOnInput: PowerOnInput = .dontChange, standby: StandbyChoice = .dontChange) {
        self.powerOnInput = powerOnInput
        self.standby = standby
    }

    /// A choice missing from the file (saved before it existed) is Don't change.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        powerOnInput = try container.decodeIfPresent(PowerOnInput.self, forKey: .powerOnInput) ?? .dontChange
        standby = try container.decodeIfPresent(StandbyChoice.self, forKey: .standby) ?? .dontChange
    }

    /// The source byte that turns the speaker on: the byte it reported,
    /// with the power bit set, the chosen input and the chosen standby
    /// time. It all goes in one write, so the speaker never starts on the
    /// old input first.
    ///
    /// A speaker that is already on keeps its input: waking the Mac after
    /// a short sleep "powers on" a speaker that never went off, and
    /// someone may be listening to another input on it.
    public func powerOnByte(from current: SourceByte) -> SourceByte {
        var byte = current.with(isPoweredOn: true)
        if !current.isPoweredOn, let input = powerOnInput.input {
            byte = byte.with(input: input)
        }
        if let mode = standby.mode {
            byte = byte.with(standby: mode)
        }
        return byte
    }

    /// The standby time to write for `reason`, or nil to leave the
    /// speaker's as it is.
    public func standbyToWrite(for reason: StandbyReason) -> StandbyMode? {
        switch reason {
        case .chosen, .connect:
            return standby.mode
        case .wake:
            // Dynamic standby: awake, use the chosen time. With no choice,
            // keep what it always did, so the speaker stays on all day.
            return standby.mode ?? .never
        case .sleep:
            // Whatever was chosen, a speaker left on while the Mac sleeps
            // goes to standby by itself.
            return .twentyMinutes
        }
    }
}

/// Why the app is writing the speaker's standby time. Logged with each write.
public enum StandbyReason: String, Sendable {
    /// The owner picked a time in Settings.
    case chosen
    /// The speaker just answered the app's connection check.
    case connect
    /// The Mac woke up (dynamic standby).
    case wake
    /// The Mac has been asleep for the power-off delay (dynamic standby).
    case sleep
}

/// How long the speaker waits before standby, as chosen in Settings.
/// Saved by name (`"sixtyMinutes"`).
public enum StandbyChoice: String, Codable, CaseIterable, Sendable {
    case dontChange
    case twentyMinutes
    case sixtyMinutes
    case never

    /// The time to write, or nil to keep the speaker's.
    public var mode: StandbyMode? {
        switch self {
        case .dontChange: return nil
        case .twentyMinutes: return .twentyMinutes
        case .sixtyMinutes: return .sixtyMinutes
        case .never: return .never
        }
    }

    /// The name Settings shows.
    public var label: String {
        mode?.label ?? "Don't change"
    }

    /// Under the row in Settings: when the choice reaches the speaker
    /// (``SpeakerController/applyStandby(_:for:)``).
    public static let settingsCaption = "Now, and each time KEF Remote connects."
}

/// The input the speaker switches to when the app turns it on. Saved by
/// name (`"optical"`), not by the speaker's 4-bit code.
public enum PowerOnInput: String, Codable, CaseIterable, Sendable {
    /// Under the row in Settings: only the app's own turn-on applies it,
    /// not KEF's remote.
    public static let settingsCaption = "When KEF Remote turns the speaker on."

    case dontChange
    case optical
    case wifi
    case bluetooth
    case aux
    case usb

    /// The input to write, or nil to keep the speaker's.
    public var input: InputSource? {
        switch self {
        case .dontChange: return nil
        case .optical: return .optical
        case .wifi: return .wifi
        // See InputSource.codeToSelect: Bluetooth is chosen with the paired code.
        case .bluetooth: return .bluetoothPaired
        case .aux: return .aux
        case .usb: return .usb
        }
    }

    /// The name Settings shows.
    public var label: String {
        input?.label ?? "Don't change"
    }
}

extension InputSource {
    /// The name Settings, the Input menu and the HUD show. Bluetooth reads
    /// the same paired or not: it's one input to whoever is listening.
    public var label: String {
        switch self {
        case .optical: return "Optical"
        case .wifi: return "Wi-Fi"
        case .bluetoothPaired, .bluetoothUnpaired: return "Bluetooth"
        case .aux: return "Aux"
        case .usb: return "USB"
        }
    }
}
