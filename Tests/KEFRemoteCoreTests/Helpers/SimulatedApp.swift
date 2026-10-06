import Foundation
@testable import KEFRemoteCore

/// The app's wiring around the speaker (`AppDelegate`), in miniature, on
/// a ``SimulatedSpeaker``: a new ``SpeakerController`` for each
/// connection, presses and toggles that skip while there is none, and a
/// ``SpeakerReconnector`` that drops it after a failure and connects
/// again after its wait. The wait runs when the test says so
/// (``runNextReconnect()``), on the shared simulated clock.
///
/// Locked, as presses come in on many tasks at once.
final class SimulatedApp: @unchecked Sendable {
    let speaker: SimulatedSpeaker
    let clock: SimulatedClock
    let log = MockKEFLog()
    let reconnector: SpeakerReconnector

    private let lock = NSLock()
    private var controller: SpeakerController?
    private var skips = 0
    private let waits: Waits
    /// The reconnector is called from one thread at a time, as on the
    /// app's main thread. Recursive: a reconnect that is refused reports
    /// the failure from inside the reconnector's scheduled run.
    private let reconnectorLock = NSRecursiveLock()

    /// Reconnects the reconnector scheduled, waiting to run.
    private final class Waits: @unchecked Sendable {
        let lock = NSLock()
        var scheduled: [(wait: Duration, run: @Sendable () -> Void)] = []
    }

    init(speaker: SimulatedSpeaker, clock: SimulatedClock) {
        self.speaker = speaker
        self.clock = clock
        let waits = Waits()
        self.waits = waits
        reconnector = SpeakerReconnector(clock: clock, log: log.handler) { wait, run in
            waits.lock.withLock { waits.scheduled.append((wait, run)) }
        }
        reconnector.dropConnection = { [weak self] in
            guard let self else { return }
            lock.withLock { self.controller = nil }
            speaker.closeConnection()
        }
        reconnector.reconnect = { [weak self] _ in self?.connect() }
    }

    /// Whether a controller is connected now.
    var isConnected: Bool { lock.withLock { controller != nil } }
    /// Commands skipped for want of a connection.
    var skipped: Int { lock.withLock { skips } }
    /// Reconnects waiting to run.
    var reconnectsWaiting: Int { waits.lock.withLock { waits.scheduled.count } }

    /// Open a connection and make its controller, as `connectToSpeaker`
    /// does. A refused open is a failure the reconnector handles.
    func connect() {
        do {
            try speaker.openConnection()
        } catch {
            log.info("connect: \(error)")
            failed(error, from: nil)
            return
        }
        let controller = SpeakerController(
            connection: speaker,
            log: log.handler,
            onReply: { [weak self] reply in
                guard case .answered = reply, let self else { return }
                reconnectorLock.withLock { self.reconnector.speakerAnswered() }
            },
            clock: clock
        )
        lock.withLock { self.controller = controller }
    }

    /// A volume key or shortcut press (`runVolumeCommand`).
    @discardableResult
    func press(_ command: VolumeCommand, step: Int) async -> VolumePressResult? {
        guard let controller = currentController() else { return nil }
        do {
            return try await controller.press(command, step: step)
        } catch {
            failed(error, from: controller)
            return nil
        }
    }

    /// The power shortcut (`togglePower`).
    @discardableResult
    func togglePower() async -> PowerToggleResult? {
        guard let controller = currentController() else { return nil }
        do {
            return try await controller.togglePower(applying: SpeakerSettings())
        } catch {
            failed(error, from: controller)
            return nil
        }
    }

    /// Let the clock reach the first waiting reconnect, and run it.
    func runNextReconnect() async {
        guard let next = waits.lock.withLock({ waits.scheduled.isEmpty ? nil : waits.scheduled.removeFirst() }) else {
            return
        }
        await clock.sleep(for: next.wait)
        reconnectorLock.withLock { next.run() }
    }

    private func currentController() -> SpeakerController? {
        lock.withLock {
            if controller == nil { skips += 1 }
            return controller
        }
    }

    /// `handleCommandError`: an error from a connection already replaced
    /// changes nothing.
    private func failed(_ error: Error, from failed: SpeakerController?) {
        reconnectorLock.withLock {
            let current = lock.withLock { controller }
            guard failed == nil || reconnector.isWaiting || failed === current else { return }
            reconnector.commandFailed(error, searchesBySelf: false)
        }
    }
}
