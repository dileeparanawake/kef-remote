import Foundation

/// Where the IP being checked came from. It decides whether a failed
/// check should look for the speaker on the network.
public enum CheckOrigin: Equatable, Sendable {
    /// The IP saved in config, at launch or on rejoining the home
    /// network. The speaker may have moved since, so a failure rediscovers.
    case savedIP
    /// The IP discovery just settled on. Searching again would loop:
    /// a speaker that is off at the wall never answers.
    case afterDiscovery
    /// The IP the user typed in settings. Discovery must not overrule it.
    case typedInSettings
}

/// What the app does once the check is done.
public enum CheckOutcome: Equatable, Sendable {
    /// The speaker answered.
    case answered
    /// The speaker could not be reached at a saved IP: look for it.
    case rediscover
    /// The speaker did not answer, and searching would not help.
    case notConnected

    /// The outcome of a check that failed with `error`.
    init(failure error: Error, origin: CheckOrigin) {
        // An empty read means something answered at that IP, so it hasn't moved.
        let isUnreachable = (error as? KEFError)?.isConnectionFailure ?? true
        self = isUnreachable && origin == .savedIP ? .rediscover : .notConnected
    }
}

/// How a check retries a refused connection. A KEF takes one connection
/// at a time, and refuses a new one for a moment after the last one closes.
public struct RefusalRetry: Sendable {
    /// Tries after the first refusal.
    public let attempts: Int
    /// The wait before each try.
    public let pause: @Sendable () async -> Void

    public init(attempts: Int, pause: @escaping @Sendable () async -> Void) {
        self.attempts = attempts
        self.pause = pause
    }

    /// Three more tries, a second apart: long enough for the speaker to
    /// let go of the old connection, short enough that the menu catches up
    /// before anyone looks.
    public static let standard = RefusalRetry(attempts: 3, pause: {
        try? await Task.sleep(for: .seconds(1))
    })
}

extension SpeakerController {
    /// Check the speaker answers, by reading its source byte, and say what
    /// to do if it doesn't. A refused connection is tried again first. The
    /// result reaches `onReply` like any other exchange.
    public func checkConnection(
        _ origin: CheckOrigin,
        refusalRetry: RefusalRetry = .standard
    ) async -> CheckOutcome {
        log(.info, "Checking the speaker answers")
        var retries = 0
        while true {
            do {
                _ = try await getSourceByte()
                return .answered
            } catch KEFError.connectionRefused where retries < refusalRetry.attempts {
                retries += 1
                log(.info, "Speaker refused the connection; trying again (\(retries) of \(refusalRetry.attempts))")
                await refusalRetry.pause()
            } catch {
                let outcome = CheckOutcome(failure: error, origin: origin)
                log(.warning, "Speaker did not answer the check (\(error)): \(outcome.nextStep)")
                return outcome
            }
        }
    }
}

private extension CheckOutcome {
    /// The second half of the failed-check log line.
    var nextStep: String {
        switch self {
        case .answered: return "it answered"
        case .rediscover: return "the saved IP may be stale, looking for the speaker"
        case .notConnected: return "not connected until the next command"
        }
    }
}
