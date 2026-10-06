import Foundation

/// What the on-screen HUD can show after a command.
public enum HUDState: Equatable, Sendable {
    case volume(level: Int)
    case muted
    case powerOn
    case powerOff
    /// The speaker switched to this input.
    case input(InputSource)
    case waking
    case error(String)
}

extension HUDState {
    /// The HUD after a command failed. When the speaker couldn't be
    /// reached it says so (the menu says what to do); any other failure
    /// shows `otherwise`, such as "Power failed".
    public static func failure(_ error: Error, otherwise message: String) -> HUDState {
        let isUnreachable = (error as? KEFError)?.isConnectionFailure ?? false
        return .error(isUnreachable ? "Can't reach the speaker" : message)
    }
}

extension HUDState {
    /// The HUD after a power toggle: which way it went. Nil when the
    /// toggle was ignored as a repeat: the one it repeated shows the HUD.
    public static func afterPowerToggle(_ result: PowerToggleResult) -> HUDState? {
        switch result {
        case .turnedOn: return .powerOn
        case .turnedOff: return .powerOff
        case .ignored: return nil
        }
    }

    /// The HUD after Turn speaker on / off in the menu: which way it went.
    /// Nil when nothing was sent (already that way, or too close to
    /// another power change).
    public static func afterPowerMenu(_ result: PowerMenuResult) -> HUDState? {
        switch result {
        case .done(.powerOn): return .powerOn
        case .done(.powerOff): return .powerOff
        case .done(.alreadyOn), .done(.alreadyOff), .ignored: return nil
        }
    }
}

extension HUDState {
    /// The HUD after Input ▸: the input the speaker read back, or why
    /// not. Never the input it only asked for.
    public static func afterInputSwitch(_ result: InputSwitchResult) -> HUDState {
        switch result {
        case .switched(let input): return .input(input)
        case .notTaken(let asked, _): return .error("\(asked.label) not available")
        case .speakerOff: return .error("Speaker is off")
        }
    }
}

/// How a ``HUDState`` looks: the icon and the line under it.
///
/// `HUDOverlay` draws it; this decides it, so it can be tested.
public struct HUDPresentation: Equatable, Sendable {
    /// An SF Symbol name.
    public let symbolName: String
    /// The line under the icon, such as "42%" or "Muted".
    public let label: String

    public init(_ state: HUDState) {
        switch state {
        case .volume(let level):
            symbolName = Self.volumeSymbol(level)
            label = "\(level)%"
        case .muted:
            symbolName = "speaker.slash.fill"
            label = "Muted"
        case .powerOn:
            symbolName = "power"
            label = "Power On"
        case .powerOff:
            symbolName = "power"
            label = "Power Off"
        case .input(let input):
            symbolName = "hifispeaker.fill"
            label = input.label
        case .waking:
            symbolName = "antenna.radiowaves.left.and.right"
            label = "Waking..."
        case .error(let message):
            symbolName = "exclamationmark.triangle.fill"
            label = message
        }
    }

    /// More waves for a louder level, like the macOS volume HUD.
    private static func volumeSymbol(_ level: Int) -> String {
        if level == 0 { return "speaker.fill" }
        if level < 33 { return "speaker.wave.1.fill" }
        if level < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
