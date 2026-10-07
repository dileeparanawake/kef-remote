import Foundation

/// Whether KEF Remote has a ``Permission``, as far as the app can tell.
///
/// ```
/// Accessibility:  AXIsProcessTrusted() ──> granted | notGranted
/// Local Network:  notCheckedYet ──speaker answered──> granted
///                               ──macOS blocked it──> notGranted
///                 notGranted ──a probe got out (LocalNetworkRetry)──> granted
/// ```
public enum PermissionStatus: String, Equatable, Sendable {
    case granted
    case notGranted
    /// Local Network only: macOS has no API to ask, so the app knows
    /// only once it has tried to reach the speaker.
    case notCheckedYet

    /// Accessibility, from `AXIsProcessTrusted()`.
    public init(accessibilityTrusted: Bool) {
        self = accessibilityTrusted ? .granted : .notGranted
    }

    /// Local Network, after the connection status changes. A reply means
    /// the app is allowed; a blocked error means it isn't. Anything else
    /// (a speaker that's off, or still being looked for) says nothing
    /// about the permission, so the last answer stands.
    public func localNetwork(after status: ConnectionStatus) -> PermissionStatus {
        switch status {
        case .connected: return .granted
        case .localNetworkBlocked: return .notGranted
        case .dormant, .noSpeaker, .searching, .connecting, .notConnected: return self
        }
    }

    /// Whether it has just been granted: the moment to start what needed it.
    public static func isNewlyGranted(from old: PermissionStatus, to new: PermissionStatus) -> Bool {
        new == .granted && old != .granted
    }
}
