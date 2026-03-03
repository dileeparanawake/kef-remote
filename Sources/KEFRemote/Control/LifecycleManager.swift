import AppKit
import KEFRemoteCore
import os

/// Monitors macOS wake/sleep lifecycle events and triggers speaker
/// power management callbacks.
///
/// When the Mac goes to sleep, a configurable delay timer starts.
/// If the Mac wakes before the timer fires, the timer is cancelled
/// and the speaker is powered on. If the timer fires (after wake from
/// a real sleep), the speaker is powered off with a 20-minute standby.
///
/// The "dynamic standby" feature sets the speaker to "never" standby
/// while the Mac is awake (so it stays on indefinitely) and switches
/// to 20-minute standby before powering off on sleep (so the speaker
/// eventually enters standby on its own if the Mac doesn't wake up).
///
/// The actual speaker commands are NOT wired up here -- that happens
/// in the integration task (Task 22). This class only provides the
/// lifecycle monitoring infrastructure and callback mechanism.
///
/// Usage:
/// ```swift
/// let lifecycle = LifecycleManager()
/// lifecycle.onWake = { print("Power on speaker") }
/// lifecycle.onSleep = { print("Power off speaker") }
/// lifecycle.onStandbyChange = { mode in print("Set standby: \(mode)") }
/// lifecycle.isEnabled = true
/// lifecycle.start()
/// ```
final class LifecycleManager {

    // MARK: - Callbacks

    /// Called when the Mac wakes and the speaker should power on.
    ///
    /// Invoked on the main thread after cancelling any pending sleep
    /// timer. The callback should issue a power-on command to the
    /// speaker.
    var onWake: (() -> Void)?

    /// Called when the sleep timer fires and the speaker should power off.
    ///
    /// Invoked on the main thread after the ``powerOffDelay`` has
    /// elapsed following a sleep notification. The callback should
    /// issue a power-off command to the speaker.
    var onSleep: (() -> Void)?

    /// Called when the speaker's standby mode should change.
    ///
    /// The parameter is the desired standby mode:
    /// - `.never` on wake (speaker stays on indefinitely)
    /// - `.twentyMinutes` before sleep power-off (speaker enters
    ///   standby on its own if the Mac doesn't wake)
    var onStandbyChange: ((StandbyMode) -> Void)?

    // MARK: - Configuration

    /// Delay in seconds before powering off after sleep. Default 60.
    ///
    /// This delay prevents unnecessary power cycling during brief
    /// sleep events (e.g. lid close with external display). If the
    /// Mac wakes before the delay elapses, the timer is cancelled
    /// and the speaker stays on.
    var powerOffDelay: TimeInterval = 60

    /// Whether lifecycle hooks are enabled.
    ///
    /// When `false`, notifications are still observed but callbacks
    /// are not triggered. This allows toggling lifecycle management
    /// without re-registering notification observers.
    var isEnabled: Bool = false

    // MARK: - Private state

    /// Timer that fires after ``powerOffDelay`` to trigger power-off.
    ///
    /// Set when a sleep notification arrives; invalidated on wake.
    /// A `nil` value means no sleep timer is pending.
    private var sleepTimer: Timer?

    /// Whether a sleep timer is logically pending.
    ///
    /// This flag guards against a race condition: when the Mac wakes
    /// from a long sleep, both `didWakeNotification` and the elapsed
    /// timer could fire in the same run loop iteration. The flag
    /// ensures that once wake processing cancels the timer, a
    /// subsequently-delivered timer callback is ignored.
    private var sleepTimerPending = false

    private let logger = Logger(
        subsystem: "com.kef-remote",
        category: "LifecycleManager"
    )

    // MARK: - Lifecycle

    /// Start observing wake/sleep notifications.
    ///
    /// Registers for both system sleep/wake and screen sleep/wake
    /// notifications on the shared workspace notification center.
    /// Call this once after configuring callbacks and enabling the
    /// manager.
    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        nc.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(handleScreensSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(handleScreensWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        logger.info("Lifecycle manager started")
    }

    /// Stop observing notifications and cancel any pending timer.
    ///
    /// Safe to call multiple times. Also called from ``deinit``.
    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        cancelSleepTimer()
        logger.info("Lifecycle manager stopped")
    }

    deinit {
        stop()
    }

    // MARK: - Notification handlers

    @objc private func handleWillSleep(_ notification: Notification) {
        guard isEnabled else { return }
        logger.debug("Received willSleepNotification")
        startSleepTimer()
    }

    @objc private func handleScreensSleep(_ notification: Notification) {
        guard isEnabled else { return }
        logger.debug("Received screensDidSleepNotification")
        startSleepTimer()
    }

    @objc private func handleDidWake(_ notification: Notification) {
        guard isEnabled else { return }
        logger.debug("Received didWakeNotification")
        cancelSleepAndPowerOn()
    }

    @objc private func handleScreensWake(_ notification: Notification) {
        guard isEnabled else { return }
        logger.debug("Received screensDidWakeNotification")
        cancelSleepAndPowerOn()
    }

    // MARK: - Timer management

    /// Start the power-off delay timer.
    ///
    /// If a timer is already running, it is invalidated and replaced.
    /// This handles the case where both `willSleepNotification` and
    /// `screensDidSleepNotification` fire for the same sleep event --
    /// only one timer runs at a time.
    private func startSleepTimer() {
        cancelSleepTimer()

        sleepTimerPending = true
        logger.info(
            "Sleep detected, starting \(self.powerOffDelay, privacy: .public)s power-off timer"
        )

        sleepTimer = Timer.scheduledTimer(
            withTimeInterval: powerOffDelay,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }

            // Check the pending flag to guard against the race where
            // wake processing already ran in this run loop iteration.
            guard self.sleepTimerPending else {
                self.logger.debug("Sleep timer fired but was already cancelled by wake")
                return
            }

            self.sleepTimerPending = false
            self.logger.info("Power-off timer fired")
            self.onStandbyChange?(.twentyMinutes)
            self.onSleep?()
        }
    }

    /// Cancel the pending sleep timer without triggering any callbacks.
    private func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerPending = false
    }

    /// Cancel the sleep timer and trigger wake callbacks.
    ///
    /// Sets standby to "never" (speaker stays on indefinitely while
    /// the Mac is awake) and calls ``onWake``.
    private func cancelSleepAndPowerOn() {
        cancelSleepTimer()
        logger.info("Wake detected, cancelling sleep timer and powering on")
        onStandbyChange?(.never)
        onWake?()
    }
}
