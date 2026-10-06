import Foundation

/// Turn speaker on / Turn speaker off in the menu, just above Input ▸.
///
/// ```
/// Connected to LSX
/// 192.168.1.80
/// ─────────────
/// Turn speaker off        the last read said on
/// Input: Optical  ▸
/// ```
///
/// The words come from the last source byte, read again as the menu
/// opens (``SourceByteRefresh``). A click does what the words say
/// (``PowerMenuAction``): Turn speaker on applies the input and standby
/// defaults, as the power shortcut does.
public struct PowerMenuItem: Equatable, Sendable {
    /// "Turn speaker off", "Turn speaker on", or "Turn speaker on/off"
    /// while the app doesn't know (before the first read, or not connected).
    public let title: String
    /// What a click does.
    public let action: PowerMenuAction
    /// Greyed out while the speaker isn't connected: a click couldn't reach it.
    public let isEnabled: Bool

    /// - Parameters:
    ///   - speakerSource: The last source byte read or written, or nil
    ///     before the first read.
    ///   - isConnected: The speaker answered the last exchange.
    public init(speakerSource: SourceByte?, isConnected: Bool) {
        isEnabled = isConnected
        // Not connected, the last byte may be old: KEF's remote can turn
        // the speaker on or off without the app seeing it.
        switch isConnected ? speakerSource?.isPoweredOn : nil {
        case true?: action = .turnOff
        case false?: action = .turnOn
        case nil: action = .toggle
        }
        title = action.title
    }
}

/// What a click on the menu's power item asks for.
public enum PowerMenuAction: Equatable, Sendable {
    case turnOn
    case turnOff
    /// Only while the app doesn't know which way the speaker is.
    case toggle

    public var title: String {
        switch self {
        case .turnOn: "Turn speaker on"
        case .turnOff: "Turn speaker off"
        case .toggle: "Turn speaker on/off"
        }
    }

    /// What to do, from the byte read at the click. The speaker can change
    /// between the menu opening and the click (KEF's remote), so a speaker
    /// already that way is left alone: writing power on to a speaker that
    /// is on would also switch it to the Input on turn-on choice.
    public func step(isPoweredOn: Bool) -> PowerMenuStep {
        switch (self, isPoweredOn) {
        case (.turnOn, true): .alreadyOn
        case (.turnOff, false): .alreadyOff
        case (.turnOn, false), (.toggle, false): .powerOn
        case (.turnOff, true), (.toggle, true): .powerOff
        }
    }
}

/// What a click on the menu's power item did.
public enum PowerMenuStep: Equatable, Sendable {
    case powerOn
    case powerOff
    /// Nothing sent: the speaker was on already.
    case alreadyOn
    /// Nothing sent: the speaker was off already.
    case alreadyOff
}

/// How a click on the menu's power item went
/// (``SpeakerController/runPowerMenuAction(_:applying:)``).
public enum PowerMenuResult: Equatable, Sendable {
    /// It read the speaker and took this step.
    case done(PowerMenuStep)
    /// Nothing sent, not even a read: too close to another power change,
    /// from the menu or the power shortcut (``PowerToggleGuard``).
    case ignored(PowerToggleGuard.Refusal)
}
