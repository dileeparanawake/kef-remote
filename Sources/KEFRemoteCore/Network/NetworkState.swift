import Foundation

/// Whether the app works on the current Wi-Fi network.
///
/// `NetworkMonitor` reads the SSID; this decides what it means.
public enum NetworkState: String, Equatable, Sendable, CustomStringConvertible {
    /// On the home network (or no home network set yet).
    case active
    /// On another network, or off Wi-Fi.
    case dormant

    public var description: String { rawValue }

    /// Decide the state from the current and home SSIDs.
    ///
    /// - No home SSID set: active, so the app works until it is set up.
    /// - Off Wi-Fi (no current SSID): dormant.
    /// - Otherwise active only when the names match exactly (case counts).
    public static func on(currentSSID: String?, homeSSID: String?) -> NetworkState {
        guard let homeSSID else { return .active }
        guard let currentSSID else { return .dormant }
        return currentSSID == homeSSID ? .active : .dormant
    }
}
