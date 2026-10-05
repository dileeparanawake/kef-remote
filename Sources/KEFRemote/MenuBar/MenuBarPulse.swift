import Combine
import KEFRemoteCore

/// Fades the orange dot in and out while it looks for the speaker.
///
/// A timer redraws the icon every ``SearchingPulse/frameInterval``, with
/// the opacity ``SearchingPulse/opacity(after:)`` gives. It runs only
/// while the dot pulses, and logs when it starts and stops:
///
/// ```
/// [menubar] orange dot pulsing
/// [menubar] orange dot stopped pulsing after 3.2 seconds
/// ```
///
/// Its own object, so the redraws touch only the icon, not the menu.
@MainActor
final class MenuBarPulse: ObservableObject {
    @Published private(set) var dotOpacity = SearchingPulse.brightestOpacity

    /// The running timer, or nil when the dot is still.
    private var ticker: Task<Void, Never>?
    private var startedAt: ContinuousClock.Instant?

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    /// Start or stop pulsing. Asking for what it already does is ignored.
    func run(_ pulsing: Bool) {
        if pulsing {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard ticker == nil else { return }
        let start = ContinuousClock.now
        startedAt = start
        dotOpacity = SearchingPulse.brightestOpacity
        log.info("orange dot pulsing")
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: SearchingPulse.frameInterval)
                guard !Task.isCancelled, let self else { return }
                dotOpacity = SearchingPulse.opacity(after: .now - start)
            }
        }
    }

    private func stop() {
        guard let ticker else { return }
        ticker.cancel()
        self.ticker = nil
        dotOpacity = SearchingPulse.brightestOpacity
        let ran = startedAt.map { ContinuousClock.now - $0 } ?? .zero
        startedAt = nil
        log.info("orange dot stopped pulsing after \(ran.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))")
    }
}
