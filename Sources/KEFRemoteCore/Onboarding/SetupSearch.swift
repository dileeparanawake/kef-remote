/// When the app looks for the speaker by itself while setup isn't
/// finished, and what a search in the background shows.
///
/// ```
/// search the app starts by itself     setup not finished,   otherwise
/// (no IP saved, unreachable, …)       step 2 not shown yet
/// ──────────────────────────────────  ────────────────────  ─────────
///                                     waits                 searches
/// a click (Find speaker, Discover)    searches              searches
///
/// step 2 shows, Auto, nothing answering ─▶ it looks for the speaker
/// HUD after a search in the background: none while setup is open
/// ```
///
/// Hand test round 7: at the first launch the app looked for the speaker
/// before step 1, with Local Network still off. The search failed and a
/// "Discovery failed" HUD showed over the setup window. Step 2 is where
/// he expects the search, and where its result shows.
public enum SetupSearch {
    /// Whether a search waits for setup's step 2.
    ///
    /// - Parameters:
    ///   - isSetupFinished: Saved in config.json.
    ///   - findSpeakerStepShown: Step 2 has shown during this run; it
    ///     searched then, so the app's own searches go on as usual.
    public static func waits(_ trigger: DiscoveryTrigger, isSetupFinished: Bool, findSpeakerStepShown: Bool) -> Bool {
        !trigger.isClick && !isSetupFinished && !findSpeakerStepShown
    }

    /// The log line for a search that waits.
    public static func waitLogLine(_ trigger: DiscoveryTrigger) -> String {
        "Not looking for the speaker by itself (\(trigger)): setup isn't finished, and its step 2 looks when it shows"
    }

    /// The HUD after a search the app ran in the background, or nil.
    /// None while the setup window is open: step 2 shows the result.
    public static func hud(after outcome: DiscoveryOutcome, setupOpen: Bool) -> HUDState? {
        guard !setupOpen else { return nil }
        switch outcome {
        case .notFound: return .error("Speaker not found")
        case .failed: return .error("Discovery failed")
        case .found, .alreadyRunning: return nil
        }
    }
}

/// Whether setup's step 2 looks for the speaker as it shows, so he
/// doesn't have to click Find speaker first.
public enum FindSpeakerOnShow: Equatable, Sendable {
    case search
    /// Why not, for the log.
    case dontSearch(String)

    public init(discovery: DiscoveryMode, connection: ConnectionStatus) {
        guard discovery.searchesBySelf else {
            self = .dontSearch("Manual: waiting for an IP")
            return
        }
        switch connection {
        case .noSpeaker, .notConnected: self = .search
        case .connected: self = .dontSearch("already connected")
        case .searching, .connecting: self = .dontSearch("a search or check is running")
        // The retry tries again once it's allowed; the line says to go Back.
        case .localNetworkBlocked: self = .dontSearch("Local Network is blocked")
        // At the launch after Restart and continue, step 2 shows before the
        // app is on the home network; the launch's own search runs then.
        case .dormant: self = .dontSearch("not on the home network yet")
        }
    }

    public var logLine: String {
        switch self {
        case .search: return "step 2 looks for the speaker as it shows (Auto, nothing answering yet)"
        case .dontSearch(let reason): return "step 2 doesn't look for the speaker as it shows: \(reason)"
        }
    }
}
