/// Volume and mute presses that wait together for one turn at the
/// speaker, added up into one change.
///
/// Holding a volume key, or pressing it quickly, sends a press every
/// tenth of a second or so. Each was a read and a write, and in the hand
/// test of 6 Oct 2026 a burst of them knocked the speaker's control
/// server over. Now presses that come while one is waiting its turn join
/// it: three ups are one write of +15, and two mutes are no change.
///
/// The rule: the level moves by the sum of the steps, clamped to 0-100
/// once; the mute flips if there was an odd number of mute presses.
public struct VolumePresses: Equatable, Sendable {
    public private(set) var ups = 0
    public private(set) var downs = 0
    public private(set) var mutes = 0
    /// What the steps add up to, in percent.
    public private(set) var levelChange = 0

    /// The speaker's volume range, in percent.
    private static let levels = 0...100

    public init() {}

    public var count: Int { ups + downs + mutes }
    public var isEmpty: Bool { count == 0 }

    /// An odd number of mute presses flips the mute; an even one leaves it.
    public var flipsMute: Bool { mutes % 2 == 1 }

    /// Add a press. `step` is how many percent a volume press moves.
    public mutating func add(_ command: VolumeCommand, step: Int) {
        switch command {
        case .up:
            ups += 1
            levelChange += step
        case .down:
            downs += 1
            levelChange -= step
        case .mute:
            mutes += 1
        }
    }

    /// The volume after these presses, from what the speaker has now.
    public func applied(to current: VolumeState) -> VolumeState {
        VolumeState(
            level: min(max(current.level + levelChange, Self.levels.lowerBound), Self.levels.upperBound),
            isMuted: current.isMuted != flipsMute
        )
    }

    /// The command the HUD shows them as: Muted / Unmuted when every press
    /// was mute, otherwise the level.
    public var hudCommand: VolumeCommand {
        if ups == 0 && downs == 0 && mutes > 0 { return .mute }
        return downs > ups ? .down : .up
    }

    /// For the log: the one command, or how many were combined.
    public var name: String {
        if count == 1 {
            return "\(ups == 1 ? VolumeCommand.up : downs == 1 ? .down : .mute)"
        }
        let parts = [(VolumeCommand.up, ups), (.down, downs), (.mute, mutes)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) ×\($0.1)" }
        return "\(count) presses combined (\(parts.joined(separator: ", ")))"
    }
}

/// What a volume or mute press did (``SpeakerController/press(_:step:)``).
public enum VolumePressResult: Equatable {
    /// It had the turn: the presses it carried, and the volume it wrote
    /// (or found, when they added up to no change).
    case sent(VolumePresses, now: VolumeState)
    /// It joined a change already waiting its turn; that one's caller
    /// shows the HUD.
    case addedToWaiting
}
