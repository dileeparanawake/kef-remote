/// How the app brings its own windows (setup, settings) to the front
/// without fighting a macOS prompt.
///
/// ```
/// window shown ─▶ 0.3 s later: in front? ─ yes ─▶ done
///                                          no ─▶ within 10 s of the macOS
///                                                Accessibility prompt?
///                                                 yes ─▶ leave it (holdBack)
///                                                 no  ─▶ try again, at most 2 times
/// ```
///
/// Hand test round 7: during the Accessibility step his Mac stopped
/// taking clicks and he had to restart it. Open Settings showed the
/// macOS Accessibility prompt, a system dialog, while the setup window
/// pulled itself to the front. The windows stay at the normal level;
/// only activation and ordering are held back.
public enum WindowFront {
    /// How long after the macOS prompt no window of the app is pulled to
    /// the front: long enough to read it and click a button.
    public static let holdBackAfterSystemPrompt: Duration = .seconds(10)

    /// How many times a window that didn't come to the front tries again.
    public static let maxTriesAgain = 2

    /// Whether a window may activate the app and order itself over others.
    ///
    /// - Parameter systemPromptAt: When the app last showed the macOS
    ///   Accessibility prompt, or nil if it hasn't this run.
    public static func mayPullToFront(now: ContinuousClock.Instant, systemPromptAt: ContinuousClock.Instant?) -> Bool {
        guard let systemPromptAt else { return true }
        return systemPromptAt.duration(to: now) >= holdBackAfterSystemPrompt
    }

    /// What a check after showing a window found.
    public enum AfterCheck: Equatable, Sendable {
        case inFront
        /// Try again: this is try number n.
        case tryAgain(Int)
        /// Tried n times: leave it.
        case giveUp(Int)
        /// The macOS prompt is up: leave it.
        case holdBack

        /// One line for the log, or nil when there's nothing to say.
        public func logLine(window: String) -> String? {
            switch self {
            case .inFront: return nil
            case .tryAgain(let n): return "\(window) not in front: trying again (\(n) of \(WindowFront.maxTriesAgain))"
            case .giveUp(let n): return "\(window) not in front after \(n) tries: leaving it (its Dock icon brings it back)"
            case .holdBack: return "\(window) not in front: not pulling it over the macOS prompt"
            }
        }
    }

    /// - Parameters:
    ///   - triesSoFar: How many times it has tried again since it was shown.
    ///   - mayPull: ``mayPullToFront(now:systemPromptAt:)``.
    public static func afterCheck(isInFront: Bool, triesSoFar: Int, mayPull: Bool) -> AfterCheck {
        if isInFront { return .inFront }
        if !mayPull { return .holdBack }
        return triesSoFar < maxTriesAgain ? .tryAgain(triesSoFar + 1) : .giveUp(triesSoFar)
    }
}
