import AppKit
import KEFRemoteCore
import os

/// Manages the app lifecycle for KEF Remote.
///
/// This is the integration hub that wires all components together:
/// 1. Loads config on launch
/// 2. Starts network monitor to determine if on the home network
/// 3. When active: connects to the speaker, registers hotkeys, starts
///    lifecycle hooks
/// 4. Hotkey triggers flow through SpeakerController and produce HUD feedback
/// 5. On command failure: disconnects, waits, reconnects (simple retry)
/// 6. Re-launch opens the settings window
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(
        subsystem: "com.kef-remote",
        category: "AppDelegate"
    )

    // MARK: - Components

    private var controller: SpeakerController?
    private var connection: TCPSpeakerConnection?
    private let mediaKeys = MediaKeyInterceptor()
    private let powerShortcuts = PowerShortcuts()
    private let lifecycle = LifecycleManager()
    private let networkMonitor = NetworkMonitor()

    // MARK: - Config

    private var config: AppConfig = AppConfig()

    /// Whether the app is currently in active mode (on home network,
    /// hotkeys registered, speaker connected).
    private var isActive = false

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background agent: no dock icon, no menu bar.
        NSApp.setActivationPolicy(.accessory)

        // 1. Load config from disk.
        loadConfig()

        // 2. Check accessibility permission (needed for media key interception).
        if !MediaKeyInterceptor.checkAccessibility(prompt: true) {
            logger.warning(
                "Accessibility permission not granted — media keys will not work"
            )
        }

        // 3. Set up all component callbacks.
        setupMediaKeyCallbacks()
        setupPowerShortcutCallbacks()
        setupLifecycleCallbacks()
        setupNetworkCallbacks()

        // 4. Start network monitor — it will call activate() or deactivate()
        //    based on whether we are on the home network.
        do {
            try networkMonitor.start()
        } catch {
            logger.error(
                "Failed to start network monitor: \(error.localizedDescription)"
            )
            // Fall back to active mode so the app still works.
            activate()
        }

        // The network state may have been evaluated during setup (before
        // the onStateChange callback was connected). Ensure we activate
        // if already on the home network.
        if networkMonitor.state == .active && !isActive {
            activate()
        }

        logger.info("KEF Remote launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        deactivate()
    }

    /// Called when the user re-launches the app while it is already running
    /// (e.g. double-clicking the app icon again, or running from terminal).
    ///
    /// Opens the settings window so the user can configure the app.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
    }

    // MARK: - Config

    private func loadConfig() {
        config = (try? AppConfig.load(from: configFileURL)) ?? AppConfig()
        applyConfig()
    }

    /// Push config values to the components that need them.
    private func applyConfig() {
        networkMonitor.homeSSID = config.network.homeSSID
        lifecycle.isEnabled = config.lifecycle.powerOnWake || config.lifecycle.powerOffSleep
        lifecycle.powerOffDelay = TimeInterval(config.lifecycle.powerOffDelay)
        applyMediaKeyModifier()
    }

    /// Read the media key modifier preference from UserDefaults and apply
    /// it to the interceptor.
    ///
    /// The SettingsView stores the modifier choice in UserDefaults under
    /// the key "mediaKeyModifier" as one of: "shift", "control", "option",
    /// "command". We map that to the corresponding CGEventFlags value.
    private func applyMediaKeyModifier() {
        let stored = UserDefaults.standard.string(forKey: "mediaKeyModifier") ?? "control"
        switch stored {
        case "control":
            mediaKeys.modifier = .maskControl
        case "option":
            mediaKeys.modifier = .maskAlternate
        case "command":
            mediaKeys.modifier = .maskCommand
        default:
            mediaKeys.modifier = .maskShift
        }
    }

    private var configFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("config.json")
    }

    // MARK: - Activation (on home network)

    /// Activate the app: connect to the speaker, register hotkeys, start
    /// lifecycle hooks. Called when the network monitor reports active state.
    private func activate() {
        guard !isActive else { return }
        isActive = true

        logger.info("Activating — on home network")

        connectToSpeaker()
        mediaKeys.start()
        powerShortcuts.register()
        lifecycle.start()
    }

    /// Deactivate the app: unregister hotkeys, stop lifecycle hooks,
    /// disconnect from the speaker. Called when the network monitor
    /// reports dormant state.
    private func deactivate() {
        guard isActive else { return }
        isActive = false

        logger.info("Deactivating — off home network")

        mediaKeys.stop()
        powerShortcuts.unregister()
        lifecycle.stop()
        disconnectSpeaker()
    }

    // MARK: - Speaker connection

    /// Connect to the speaker using the stored IP address, or trigger
    /// discovery if no IP is configured.
    private func connectToSpeaker() {
        guard let ip = config.speaker?.lastKnownIp else {
            logger.warning("No speaker IP configured — attempting discovery")
            discoverSpeaker()
            return
        }

        let conn = TCPSpeakerConnection(host: ip)
        self.connection = conn
        self.controller = SpeakerController(connection: conn)
        logger.info("Connected to speaker at \(ip)")
    }

    /// Disconnect from the speaker and clear the controller.
    private func disconnectSpeaker() {
        connection?.disconnect()
        connection = nil
        controller = nil
    }

    /// Run SSDP discovery to find a speaker on the local network.
    /// If found, saves the IP to config and connects.
    private func discoverSpeaker() {
        Task {
            do {
                let results = try await SSDPDiscovery.discover(timeout: 5)
                guard let first = results.first else {
                    logger.warning("No speakers found on network")
                    await MainActor.run {
                        HUDOverlay.show(.error("No speakers found"))
                    }
                    return
                }

                await MainActor.run {
                    // Save the discovered IP.
                    if config.speaker == nil {
                        config.speaker = AppConfig.SpeakerConfig()
                    }
                    config.speaker?.lastKnownIp = first.ip
                    try? AppConfig.save(config, to: configFileURL)

                    connectToSpeaker()
                }
            } catch {
                logger.error("Discovery failed: \(error.localizedDescription)")
                await MainActor.run {
                    HUDOverlay.show(.error("Discovery failed"))
                }
            }
        }
    }

    // MARK: - Media key callbacks

    private func setupMediaKeyCallbacks() {
        mediaKeys.onMediaKey = { [weak self] action in
            guard let self, let controller = self.controller else { return }

            Task {
                do {
                    switch action {
                    case .volumeUp:
                        try await controller.raiseVolume(by: 5)
                        let state = try await controller.getVolume()
                        await MainActor.run {
                            HUDOverlay.show(.volume(level: state.level))
                        }
                    case .volumeDown:
                        try await controller.lowerVolume(by: 5)
                        let state = try await controller.getVolume()
                        await MainActor.run {
                            HUDOverlay.show(.volume(level: state.level))
                        }
                    case .mute:
                        try await controller.toggleMute()
                        let state = try await controller.getVolume()
                        await MainActor.run {
                            if state.isMuted {
                                HUDOverlay.show(.muted)
                            } else {
                                HUDOverlay.show(.volume(level: state.level))
                            }
                        }
                    }
                } catch {
                    self.logger.error(
                        "Media key command failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Command failed"))
                    }
                    self.handleCommandError()
                }
            }
        }
    }

    // MARK: - Power shortcut callbacks

    private func setupPowerShortcutCallbacks() {
        powerShortcuts.onPowerOn = { [weak self] in
            guard let self, let controller = self.controller else { return }

            HUDOverlay.show(.waking)
            Task {
                do {
                    try await controller.powerOn()
                    await MainActor.run {
                        HUDOverlay.show(.powerOn)
                    }
                } catch {
                    self.logger.error(
                        "Power on failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Power on failed"))
                    }
                }
            }
        }

        powerShortcuts.onPowerOff = { [weak self] in
            guard let self, let controller = self.controller else { return }

            Task {
                do {
                    try await controller.powerOff()
                    await MainActor.run {
                        HUDOverlay.show(.powerOff)
                    }
                } catch {
                    self.logger.error(
                        "Power off failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Power off failed"))
                    }
                }
            }
        }

        powerShortcuts.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Lifecycle callbacks

    private func setupLifecycleCallbacks() {
        lifecycle.onWake = { [weak self] in
            guard let self, let controller = self.controller else { return }
            guard self.config.lifecycle.powerOnWake else { return }

            HUDOverlay.show(.waking)
            Task {
                do {
                    try await controller.powerOn()
                    await MainActor.run {
                        HUDOverlay.show(.powerOn)
                    }
                } catch {
                    self.logger.error(
                        "Wake power-on failed: \(error.localizedDescription)"
                    )
                }
            }
        }

        lifecycle.onSleep = { [weak self] in
            guard let self, let controller = self.controller else { return }
            guard self.config.lifecycle.powerOffSleep else { return }

            Task {
                do {
                    try await controller.powerOff()
                } catch {
                    self.logger.error(
                        "Sleep power-off failed: \(error.localizedDescription)"
                    )
                }
            }
        }

        lifecycle.onStandbyChange = { [weak self] mode in
            guard let self, let controller = self.controller else { return }

            Task {
                do {
                    try await controller.setStandby(mode)
                } catch {
                    self.logger.error(
                        "Standby change failed: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    // MARK: - Network callbacks

    private func setupNetworkCallbacks() {
        networkMonitor.homeSSID = config.network.homeSSID

        networkMonitor.onStateChange = { [weak self] state in
            switch state {
            case .active:
                self?.activate()
            case .dormant:
                self?.deactivate()
            }
        }
    }

    // MARK: - Error handling

    /// Simple error recovery: disconnect and reconnect after a brief delay.
    ///
    /// On command failure, we tear down the current connection and attempt
    /// to reconnect after 2 seconds. If the speaker has changed IP, a
    /// future enhancement could trigger re-discovery here.
    private func handleCommandError() {
        disconnectSpeaker()

        // Try to reconnect after a brief delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.isActive else { return }
            self.connectToSpeaker()
        }
    }
}
