import Foundation

/// Whether an error means macOS isn't letting KEF Remote on the local
/// network (System Settings > Privacy & Security > Local Network).
///
/// macOS doesn't say so directly: a blocked app's packets fail with
/// "No route to host" (errno 65) or "Network is down" (errno 50).
public enum LocalNetworkPermission {
    /// The errno values macOS gives a blocked app.
    static let deniedCodes: Set<POSIXErrorCode> = [.EHOSTUNREACH, .ENETDOWN]

    /// True when `error` is one macOS gives an app it keeps off the local network.
    public static func isDenied(by error: Error) -> Bool {
        if case .localNetworkBlocked = error as? KEFError { return true }
        if let socketError = error as? SocketError,
           let code = POSIXErrorCode(rawValue: socketError.code) {
            return deniedCodes.contains(code)
        }
        return false
    }
}
