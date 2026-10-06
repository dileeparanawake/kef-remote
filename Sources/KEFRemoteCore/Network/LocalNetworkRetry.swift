import Foundation

/// While macOS keeps KEF Remote off the local network, try again every
/// few seconds, so allowing it in System Settings (or the macOS prompt)
/// takes effect without a click. Runs whether or not the guide is open.
///
/// ```
/// every 5 s, from the menu bar's status:
///   localNetworkBlocked ─▶ probe: one M-SEARCH
///                            blocked  ─▶ keep waiting
///                            allowed  ─▶ Auto: rediscover / Manual: reconnect
///   searching, connecting ─▶ wait for that answer
///   anything else ─────────▶ stop (the speaker answered, or macOS let it out)
/// ```
///
/// The probe, not a full retry, runs while it's blocked, so the menu bar
/// doesn't flick to Searching every 5 seconds and the log gets one line.
public enum LocalNetworkRetry: Equatable, Sendable {
    /// Still blocked: ask again on the next tick.
    case keepWaiting
    /// Allowed, in Auto: look for the speaker, which ends in a check.
    case rediscover
    /// Allowed, in Manual: check the saved IP again. Manual never searches by itself.
    case reconnect

    /// How long between asks. Short enough that the row turns green soon
    /// after he allows it; a probe that macOS blocks never leaves the Mac.
    public static let interval: Duration = .seconds(5)

    /// What one tick does.
    public enum Tick: Equatable, Sendable {
        case probe
        case wait
        case stop
    }

    /// The tick, from the menu bar's connection status.
    public static func tick(after status: ConnectionStatus) -> Tick {
        switch status {
        case .localNetworkBlocked: return .probe
        case .searching, .connecting: return .wait
        case .connected, .notConnected, .noSpeaker, .dormant: return .stop
        }
    }

    /// What to do after the probe. A failure that isn't the permission
    /// says nothing either way, so the full attempt finds out.
    public static func afterProbe(_ result: LocalNetworkProbe.Result, discovery: DiscoveryMode) -> LocalNetworkRetry {
        switch result {
        case .blocked: return .keepWaiting
        case .allowed, .failed: return discovery.searchesBySelf ? .rediscover : .reconnect
        }
    }
}

/// Asks macOS whether KEF Remote may use the local network, by sending
/// one SSDP M-SEARCH and closing the socket without listening. A blocked
/// app's send fails at once ("No route to host"); an allowed one gets out.
/// Nothing is saved and no IP changes, so Manual's promise holds.
public struct LocalNetworkProbe: Sendable {
    public enum Result: Equatable, Sendable {
        case allowed
        case blocked
        /// Some other socket failure, with its reason, for the log.
        case failed(String)
    }

    private let makeSocket: @Sendable () throws -> DatagramSocket

    public init(makeSocket: @escaping @Sendable () throws -> DatagramSocket) {
        self.makeSocket = makeSocket
    }

    /// A probe on the real network, with the socket discovery uses.
    public static func onNetwork() -> LocalNetworkProbe {
        LocalNetworkProbe(makeSocket: { try BSDDatagramSocket() })
    }

    public func run() -> Result {
        do {
            let socket = try makeSocket()
            defer { socket.close() }
            try socket.send(SSDPSearch.mediaRendererRequest, toHost: SSDPSearch.multicastHost, port: SSDPSearch.multicastPort)
            return .allowed
        } catch {
            return LocalNetworkPermission.isDenied(by: error) ? .blocked : .failed("\(error)")
        }
    }
}

extension PermissionStatus {
    /// Local Network, after a probe: a packet that got out means allowed,
    /// even while the speaker is off and can't answer.
    public func localNetwork(after probe: LocalNetworkProbe.Result) -> PermissionStatus {
        switch probe {
        case .allowed: return .granted
        case .blocked: return .notGranted
        case .failed: return self
        }
    }
}
