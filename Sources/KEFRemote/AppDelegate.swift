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
/// 6. Keeps the menu bar status up to date (``MenuBarModel``)
/// 7. Opens the settings window from the menu, or when the app is
///    launched again while running, and applies settings changes live
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = AppLogger(
        subsystem: "com.kef-remote",
        category: "AppDelegate"
    )

    /// Logger for speaker communication — protocol and operations.
    /// Receives events from SpeakerController and TCPSpeakerConnection.
    /// CLI: log stream --predicate 'subsystem == "com.kef-remote"' --level debug
    private let speakerLogger = AppLogger(
        subsystem: "com.kef-remote",
        category: "speaker"
    )

    /// Shared log handler passed to SpeakerController and TCPSpeakerConnection.
    /// Routes KEFLogLevel to AppLogger, which outputs to both os_log and stderr.
    private lazy var speakerLogHandler: KEFLogHandler = { [weak self] level, message in
        guard let self else { return }
        switch level {
        case .debug: self.speakerLogger.debug(message)
        case .info:  self.speakerLogger.info(message)
        case .warning: self.speakerLogger.warning(message)
        case .error: self.speakerLogger.error(message)
        }
    }

    /// Logger for discovery: what it sent, heard, kept and dropped.
    private let discoveryLogger = AppLogger(
        subsystem: "com.kef-remote",
        category: "discovery"
    )

    // MARK: - Menu bar and settings

    /// What the menu bar icon and menu show. Read by ``KEFRemoteApp``.
    let menuBar = MenuBarModel()

    private lazy var settingsModel = SettingsModel(
        savedIP: config.speaker?.lastKnownIp,
        actions: SettingsActions(
            saveSpeakerIP: { [weak self] ip in self?.saveSpeakerIP(ip) },
            discoverSpeaker: { [weak self] in
                await self?.runDiscovery(trigger: "Discover in settings") ?? .failed("app is closing")
            },
            applyModifier: { [weak self] choice in
                self?.mediaKeys.modifier = choice.eventFlags
                self?.logger.info("Media key modifier is now \(choice.rawValue)")
            }
        )
    )

    private lazy var settingsWindow = SettingsWindowController(model: settingsModel)

    // MARK: - Components

    private lazy var finder = SpeakerFinder.onNetwork(log: discoveryLogger)
    private var isDiscovering = false

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
        // Diagnostic: NSLog always reaches logd regardless of os_log configuration.
        // If this appears in Console.app but Logger entries don't, os_log is broken
        // for this process. If this also doesn't appear, the code path is not running.
        NSLog("[KEFRemote] applicationDidFinishLaunching — NSLog smoke test")

        // Run as a background agent: no Dock icon. The menu bar icon
        // comes from the MenuBarExtra scene in KEFRemoteApp.
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
        showSettings(source: .reopen)
        return false
    }

    /// Logged so the settings window's "came to the front" check can be
    /// read alongside it.
    func applicationDidBecomeActive(_ notification: Notification) {
        logger.info("App became active")
    }

    /// Open the settings window and bring it to the front.
    func showSettings(source: SettingsWindowController.Source) {
        settingsWindow.show(source: source)
    }

    // MARK: - Config

    private func loadConfig() {
        config = (try? AppConfig.load(from: configFileURL)) ?? AppConfig()
        menuBar.showSpeaker(config.speaker)
        applyConfig()
    }

    /// Push config values to the components that need them.
    private func applyConfig() {
        networkMonitor.homeSSID = config.network.homeSSID
        lifecycle.isEnabled = config.lifecycle.powerOnWake || config.lifecycle.powerOffSleep
        lifecycle.powerOffDelay = TimeInterval(config.lifecycle.powerOffDelay)
        applyMediaKeyModifier()
    }

    /// Apply the saved media key modifier to the interceptor at launch.
    /// The settings window applies later changes through ``settingsModel``.
    private func applyMediaKeyModifier() {
        mediaKeys.modifier = MediaKeyModifier.stored.eventFlags
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

        menuBar.set(.idle(isActive: true, speakerIP: config.speaker?.lastKnownIp), reason: "on home network")
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
        menuBar.set(.dormant, reason: "off home network")

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
            discoverInBackground(trigger: "no IP saved")
            return
        }

        let conn = TCPSpeakerConnection(host: ip, log: speakerLogHandler)
        self.connection = conn
        self.controller = SpeakerController(connection: conn, log: speakerLogHandler)
        logger.info("Speaker configured at \(ip) — connection opens on first command")
    }

    /// Disconnect from the speaker and clear the controller.
    private func disconnectSpeaker() {
        connection?.disconnect()
        connection = nil
        controller = nil
    }

    /// Save an IP typed in settings, and connect to it.
    private func saveSpeakerIP(_ ip: String) {
        var speaker = config.speaker ?? AppConfig.SpeakerConfig()
        speaker.lastKnownIp = ip
        saveSpeaker(speaker)
        reconnect(reason: "IP changed in settings")
    }

    /// Drop the current connection and connect to the saved IP.
    private func reconnect(reason: String) {
        disconnectSpeaker()
        if isActive { connectToSpeaker() }
        menuBar.set(.idle(isActive: isActive, speakerIP: config.speaker?.lastKnownIp), reason: reason)
    }

    /// Find the speaker with SSDP, save its IP (and MAC, if none was saved),
    /// then connect. Runs when no IP is saved, when connecting fails (the
    /// speaker may have a new IP), and from Discover in settings.
    private func runDiscovery(trigger: String) async -> DiscoveryOutcome {
        guard !isDiscovering else {
            logger.info("Discovery already running")
            return .alreadyRunning
        }
        isDiscovering = true
        defer { isDiscovering = false }

        let statusBefore = menuBar.status
        menuBar.set(.searching, reason: "discovery started: \(trigger)")

        // If nothing is found, a failed speaker stays failed. Otherwise
        // go back to what the config says.
        let statusIfNotFound: () -> ConnectionStatus = { [unowned self] in
            statusBefore == .error
                ? .error
                : .idle(isActive: self.isActive, speakerIP: self.config.speaker?.lastKnownIp)
        }

        do {
            guard let updated = try await finder.rediscover(config.speaker) else {
                menuBar.set(statusIfNotFound(), reason: "discovery found nothing")
                return .notFound
            }
            saveSpeaker(updated)
            reconnect(reason: "discovery found the speaker")
            return .found(updated)
        } catch {
            logger.error("Discovery failed: \(error)")
            menuBar.set(statusIfNotFound(), reason: "discovery failed")
            return .failure(error)
        }
    }

    /// Run discovery without waiting, and show a HUD if it finds nothing.
    private func discoverInBackground(trigger: String) {
        Task {
            switch await runDiscovery(trigger: trigger) {
            case .notFound: HUDOverlay.show(.error("Speaker not found"))
            case .failed: HUDOverlay.show(.error("Discovery failed"))
            case .found, .alreadyRunning: break
            }
        }
    }

    private func saveSpeaker(_ speaker: AppConfig.SpeakerConfig) {
        config.speaker = speaker
        menuBar.showSpeaker(speaker)
        settingsModel.showSavedIP(speaker.lastKnownIp)
        do {
            try AppConfig.save(config, to: configFileURL)
            logger.info("Saved speaker at \(speaker.lastKnownIp ?? "unknown IP")")
        } catch {
            logger.error("Could not save config: \(error.localizedDescription)")
        }
    }

    // MARK: - Command results

    /// Record a command's result in the menu bar icon.
    private func commandSucceeded(_ command: String) {
        menuBar.set(.ok, reason: "\(command) succeeded")
    }

    private func commandFailed(_ command: String) {
        menuBar.set(.error, reason: "\(command) failed")
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
                        let state = try await controller.getVolumeState()
                        await MainActor.run {
                            HUDOverlay.show(.volume(level: state.level))
                        }
                    case .volumeDown:
                        try await controller.lowerVolume(by: 5)
                        let state = try await controller.getVolumeState()
                        await MainActor.run {
                            HUDOverlay.show(.volume(level: state.level))
                        }
                    case .mute:
                        try await controller.toggleMute()
                        let state = try await controller.getVolumeState()
                        await MainActor.run {
                            if state.isMuted {
                                HUDOverlay.show(.muted)
                            } else {
                                HUDOverlay.show(.volume(level: state.level))
                            }
                        }
                    }
                    await MainActor.run { self.commandSucceeded("\(action)") }
                } catch {
                    self.logger.error(
                        "Media key command failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Command failed"))
                        self.commandFailed("\(action)")
                    }
                    self.handleCommandError(error)
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
                        self.commandSucceeded("power on")
                    }
                } catch {
                    self.logger.error(
                        "Power on failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Power on failed"))
                        self.commandFailed("power on")
                    }
                    self.handleCommandError(error)
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
                        self.commandSucceeded("power off")
                    }
                } catch {
                    self.logger.error(
                        "Power off failed: \(error.localizedDescription)"
                    )
                    await MainActor.run {
                        HUDOverlay.show(.error("Power off failed"))
                        self.commandFailed("power off")
                    }
                    self.handleCommandError(error)
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
                        self.commandSucceeded("wake power-on")
                    }
                } catch {
                    self.logger.error(
                        "Wake power-on failed: \(error.localizedDescription)"
                    )
                    await MainActor.run { self.commandFailed("wake power-on") }
                    self.handleCommandError(error)
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

    /// Recover from a failed command.
    ///
    /// If the speaker could not be reached, it may have a new IP, so run
    /// discovery (which saves the new IP and reconnects). Otherwise
    /// disconnect and reconnect to the same IP after 2 seconds.
    private func handleCommandError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.disconnectSpeaker()

            if let kefError = error as? KEFError, kefError.isConnectionFailure {
                self.logger.info("Could not reach the speaker (\(kefError)) — rediscovering")
                self.discoverInBackground(trigger: "speaker unreachable")
                return
            }

            self.logger.info("Command error — disconnecting and reconnecting in 2s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.isActive else { return }
                self.logger.info("Reconnecting to speaker")
                self.connectToSpeaker()
            }
        }
    }
}
