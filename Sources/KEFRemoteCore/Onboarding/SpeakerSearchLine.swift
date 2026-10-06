/// The line under Find speaker in step 2 of setup.
///
/// ```
/// menu bar status        last search    line
/// connected              any            ✓ Found LSX at 192.168.1.80
/// searching              any            ◌ Looking for the speaker…
/// localNetworkBlocked    any            Local Network is blocked: click Back and allow it
/// anything else          found nothing  Not found: check it's on and on this network
/// connecting             -              ◌ Checking the speaker at 192.168.1.80 answers…
/// notConnected           -              No answer at 192.168.1.80: check it's on and …
/// noSpeaker, dormant     -              (nothing yet)
/// ```
///
/// Read from the menu bar's status, so a speaker the app found by itself
/// before step 2 shows as found straight away.
public enum SpeakerSearchLine: Equatable, Sendable {
    case notStarted
    case searching
    case checking(ip: String)
    case found(name: String, ip: String)
    case notFound
    case noAnswer(ip: String)
    case localNetworkBlocked

    /// - Parameters:
    ///   - connection: The menu bar's status.
    ///   - speaker: The saved speaker, for its name and IP.
    ///   - searchFoundNothing: The last Find speaker in step 2 found no
    ///     speaker, and nothing has been tried since.
    public init(connection: ConnectionStatus, speaker: AppConfig.SpeakerConfig?, searchFoundNothing: Bool) {
        let ip = speaker?.lastKnownIp ?? ""
        switch connection {
        case .connected: self = .found(name: speaker?.name ?? "the speaker", ip: ip)
        case .searching: self = .searching
        case .localNetworkBlocked: self = .localNetworkBlocked
        // After a miss the app checks the saved IP again; the miss stays
        // until that check answers, so the line doesn't flick.
        case _ where searchFoundNothing: self = .notFound
        case .connecting: self = .checking(ip: ip)
        case .notConnected: self = .noAnswer(ip: ip)
        case .noSpeaker, .dormant: self = .notStarted
        }
    }

    /// The words, or nil before anything has been tried.
    public var text: String? {
        switch self {
        case .notStarted: return nil
        case .searching: return "Looking for the speaker…"
        case .checking(let ip): return "Checking the speaker at \(ip) answers…"
        case .found(let name, let ip): return "Found \(name) at \(ip)"
        case .notFound: return "Not found: check it's on and on this network"
        case .noAnswer(let ip): return "No answer at \(ip): check it's on and on this network"
        case .localNetworkBlocked: return "Local Network is blocked: click Back and allow it"
        }
    }

    /// A spinner beside it, like the menu bar's orange dot.
    public var isBusy: Bool {
        switch self {
        case .searching, .checking: return true
        default: return false
        }
    }

    /// Offer typing the IP instead. Not while blocked: Manual is blocked too.
    public var offersManual: Bool {
        switch self {
        case .notFound, .noAnswer: return true
        default: return false
        }
    }
}
