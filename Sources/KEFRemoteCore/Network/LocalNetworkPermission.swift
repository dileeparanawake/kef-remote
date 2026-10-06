import Foundation

/// Whether an error means macOS isn't letting KEF Remote on the local
/// network (System Settings > Privacy & Security > Local Network).
///
/// macOS doesn't say so directly: a blocked app's packets fail with
/// "No route to host" (errno 65), "Network is unreachable" (errno 51) or
/// "Network is down" (errno 50). Discovery's BSD socket throws a
/// ``SocketError`` with the errno; a TCP connection becomes
/// ``KEFError/localNetworkBlocked(_:)``.
///
/// Errno 51 is also what a Mac with no network at all gets. That's rare
/// on a Mac with a speaker to control, and naming the setting then is a
/// smaller harm than missing it (hand test round 7: Local Network off,
/// `sendto` failed with errno 51, and nothing named the setting).
public enum LocalNetworkPermission {
    /// The errno values macOS gives a blocked app.
    static let deniedCodes: Set<POSIXErrorCode> = [.EHOSTUNREACH, .ENETUNREACH, .ENETDOWN]

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
