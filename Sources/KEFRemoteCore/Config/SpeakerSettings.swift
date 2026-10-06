/// What the app sets on the speaker, chosen in Settings. Saved in
/// config.json under `"speakerSettings"`. Every choice starts at Don't
/// change, so a new install leaves the speaker as its owner set it.
public struct SpeakerSettings: Codable, Equatable, Sendable {
    /// The input the speaker switches to when the app turns it on.
    public var powerOnInput: PowerOnInput

    public init(powerOnInput: PowerOnInput = .dontChange) {
        self.powerOnInput = powerOnInput
    }

    /// The source byte that turns the speaker on: the byte it reported,
    /// with the power bit set and the chosen input. It all goes in one
    /// write, so the speaker never starts on the old input first.
    ///
    /// A speaker that is already on keeps its input: waking the Mac after
    /// a short sleep "powers on" a speaker that never went off, and
    /// someone may be listening to another input on it.
    public func powerOnByte(from current: SourceByte) -> SourceByte {
        var byte = current.with(isPoweredOn: true)
        if !current.isPoweredOn, let input = powerOnInput.input {
            byte = byte.with(input: input)
        }
        return byte
    }
}

/// The input the speaker switches to when the app turns it on. Saved by
/// name (`"optical"`), not by the speaker's 4-bit code.
public enum PowerOnInput: String, Codable, CaseIterable, Sendable {
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
        // The paired code (1001) is the one kefctl writes to select
        // Bluetooth. The unpaired code (1111) is how the speaker reports
        // Bluetooth while nothing is paired, not a choice to make.
        case .bluetooth: return .bluetoothPaired
        case .aux: return .aux
        case .usb: return .usb
        }
    }

    /// The name Settings shows.
    public var label: String {
        switch self {
        case .dontChange: return "Don't change"
        case .optical: return "Optical"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .aux: return "Aux"
        case .usb: return "USB"
        }
    }
}
