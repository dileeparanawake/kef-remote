import Foundation

/// Whether the media key tap (the volume keys) is on, as the app last
/// started or stopped it.
public enum MediaKeyTapState: String, Equatable, Sendable {
    /// Off the home network: the app stops the keys on purpose.
    case notStarted
    case running
    /// The app tried, and macOS refused it.
    case refused

    /// - Parameters:
    ///   - isActive: On the home network, where the app starts the tap.
    ///   - isRunning: The tap exists now.
    public init(isActive: Bool, isRunning: Bool) {
        if !isActive {
            self = .notStarted
        } else {
            self = isRunning ? .running : .refused
        }
    }
}

/// The line under the permissions on setup step 1 (and in Permissions…),
/// once Accessibility is allowed, so he knows whether the volume keys
/// work or need a restart (hand test round 5).
///
/// ```
/// Volume keys ready ✓
/// The volume keys start after a restart.        [Restart KEF Remote]
/// The volume keys start on your home network.
/// ```
public enum VolumeKeysLine: Equatable, Sendable {
    case ready
    /// Allowed, but macOS still refuses the tap: only a new process gets it.
    case needsRestart
    case startsOnHomeNetwork

    /// Nil without Accessibility: the tap can't start, a restart wouldn't
    /// help, and the Accessibility row already says what to do.
    public init?(accessibility: PermissionStatus, tap: MediaKeyTapState) {
        guard accessibility == .granted else { return nil }
        switch tap {
        case .running: self = .ready
        case .refused: self = .needsRestart
        case .notStarted: self = .startsOnHomeNetwork
        }
    }

    public var text: String {
        switch self {
        case .ready: "Volume keys ready ✓"
        case .needsRestart: "The volume keys start after a restart."
        case .startsOnHomeNetwork: "The volume keys start on your home network."
        }
    }

    /// Shows Restart KEF Remote beside the line.
    public var offersRestart: Bool { self == .needsRestart }
}
