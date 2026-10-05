import AppKit
import KEFRemoteCore
import os

/// Manages the app lifecycle for KEF Remote.
///
/// This is the integration hub that wires all components together:
/// 1. Loads config on launch
/// 2. Starts network monitor to determine if on the home network
/// 3. When active: sets up the speaker connection (it opens on the
///    first command), registers hotkeys, starts lifecycle hooks
/// 4. Hotkey triggers flow through SpeakerController and produce HUD feedback
/// 5. On a failed check of the saved IP, or a failed command: in Auto
///    discovery, rediscovers if the speaker was unreachable (it may have a
///    new IP); otherwise reconnects after 2 seconds
/// 6. Keeps the menu bar's connected state live (``MenuBarModel``):
///    every exchange with the speaker reports whether it answered
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
        discovery: config.discovery,
        actions: SettingsActions(
            saveSpeakerIP: { [weak self] ip in self?.saveSpeakerIP(ip) },
            discoverSpeaker: { [weak self] in
                await self?.runDiscovery(trigger: "Discover in settings") ?? .failed("app is closing")
            },
            applyModifier: { [weak self] choice in
                self?.mediaKeys.modifier = choice.eventFlags
                self?.logger.info("Media key modifier is now \(choice.rawValue)")
            },
            applyDiscovery: { [weak self] mode in self?.applyDiscovery(mode) }
        )
    )

    private lazy var settingsWindow = SettingsWindowController(model: settingsModel, menuBar: menuBar)

    // MARK: - Components

    private lazy var finder = SpeakerFinder.onNetwork(log: discoveryLogger)
    private var isDiscovering = false

    private var controller: SpeakerController?
    private var connection: TCPSpeakerConnection?
    private let mediaKeys = MediaKeyInterceptor()
    private let shortcuts = GlobalShortcuts()
    private let lifecycle = LifecycleManager()
    private let networkMonitor = NetworkMonitor()

    // MARK: - Config

    private var config: AppConfig = AppConfig()

    /// Whether the app is currently in active mode (on home network,
    /// hotkeys registered, speaker connected).
    private var isActive = false

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        setupShortcuts()
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

    /// Run discovery from "Find speaker" in the menu. A HUD says if it
    /// finds nothing; the menu bar shows the rest.
    func findSpeaker() {
        discoverInBackground(trigger: "Find speaker in menu")
    }

    /// Open the settings window and bring it to the front.
    func showSettings(source: SettingsWindowController.Source) {
        settingsWindow.show(source: source)
    }

    // MARK: - Config

    private func loadConfig() {
        do {
            config = try AppConfig.load(from: configFileURL)
            logger.info("Loaded config from \(configFileURL.path)")
        } catch {
            // A broken file falls back to defaults, as before, but says so.
            logger.error("Could not read \(configFileURL.path), using defaults: \(error)")
            config = AppConfig()
        }
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

    private let configFileURL = AppConfig.defaultFileURL

    // MARK: - Activation (on home network)

    /// Activate the app: connect to the speaker, register hotkeys, start
    /// lifecycle hooks. Called when the network monitor reports active state.
    private func activate() {
        guard !isActive else { return }
        isActive = true

        logger.info("Activating — on home network")

        menuBar.set(.idle(isActive: true, speakerIP: config.speaker?.lastKnownIp), reason: "on home network")
        connectToSpeaker(.savedIP)
        mediaKeys.start()
        shortcuts.setEnabled(true, reason: "on home network")
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
        shortcuts.setEnabled(false, reason: "off home network")
        lifecycle.stop()
        disconnectSpeaker()
    }

    // MARK: - Speaker connection

    /// Connect to the speaker using the stored IP address, or trigger
    /// discovery if no IP is configured.
    ///
    /// - Parameter origin: Where the IP came from. A saved IP that doesn't
    ///   answer starts discovery, so the first key press finds the speaker.
    private func connectToSpeaker(_ origin: CheckOrigin) {
        guard let ip = config.speaker?.lastKnownIp else {
            guard config.discovery.searchesBySelf else {
                logger.warning("No speaker IP configured, and discovery is Manual: waiting for an IP in Settings")
                return
            }
            logger.warning("No speaker IP configured — attempting discovery")
            discoverInBackground(trigger: "no IP saved")
            return
        }

        let conn = TCPSpeakerConnection(host: ip, log: speakerLogHandler)
        let controller = SpeakerController(
            connection: conn,
            log: speakerLogHandler,
            onReply: { [weak self, weak conn] reply in
                Task { @MainActor in self?.showReply(reply, from: conn) }
            }
        )
        self.connection = conn
        self.controller = controller
        logger.info("Speaker configured at \(ip) — checking it answers")
        menuBar.set(.connecting, reason: "checking \(ip)")
        checkSpeaker(controller, on: conn, origin: origin)
    }

    /// Check the speaker answers. If the saved IP has gone stale, look
    /// for the speaker now rather than on the first key press.
    private func checkSpeaker(_ controller: SpeakerController, on conn: TCPSpeakerConnection, origin: CheckOrigin) {
        Task {
            let outcome = await controller.checkConnection(origin, discovery: config.discovery)
            guard outcome == .rediscover else { return }
            guard conn === connection else {
                logger.info("Check failed, but a newer connection has taken over; not rediscovering")
                return
            }
            rediscover(reason: "the saved IP did not answer the check")
        }
    }

    /// The speaker could not be reached, so it may have a new IP. Drop the
    /// connection and run discovery, which saves the new IP and reconnects.
    private func rediscover(reason: String) {
        disconnectSpeaker()
        logger.info("Could not reach the speaker (\(reason)) — rediscovering")
        discoverInBackground(trigger: "speaker unreachable")
    }

    /// Show whether the speaker answered, unless the reply came from a
    /// connection that has since been dropped (a reconnect, or going dormant).
    /// Replies during discovery are dropped too: it ends by checking again.
    private func showReply(_ reply: SpeakerReply, from conn: TCPSpeakerConnection?) {
        guard let conn, conn === connection, !isDiscovering else { return }
        switch reply {
        case .answered:
            menuBar.set(.connected, reason: "speaker answered")
        case .unreachable(let reason):
            menuBar.set(.notConnected, reason: "speaker unreachable: \(reason)")
        case .localNetworkBlocked(let reason):
            menuBar.set(.localNetworkBlocked, reason: "Local Network blocked: \(reason)")
        }
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
        reconnect(.typedInSettings, reason: "IP changed in settings")
    }

    /// Drop the current connection and connect to the saved IP.
    private func reconnect(_ origin: CheckOrigin, reason: String) {
        disconnectSpeaker()
        menuBar.set(.idle(isActive: isActive, speakerIP: config.speaker?.lastKnownIp), reason: reason)
        if isActive { connectToSpeaker(origin) }
    }

    /// Find the speaker with SSDP, save its IP (and MAC, if none was saved),
    /// then connect, or keep the connection if it is already on that IP. Runs when no IP is saved, when a command can't reach
    /// the speaker (it may have a new IP), from Discover in settings and
    /// from Find speaker in the menu.
    private func runDiscovery(trigger: String) async -> DiscoveryOutcome {
        guard !isDiscovering else {
            logger.info("Discovery already running")
            return .alreadyRunning
        }
        isDiscovering = true
        defer { isDiscovering = false }

        menuBar.set(.searching, reason: "discovery started: \(trigger)")

        do {
            guard let updated = try await finder.rediscover(config.speaker) else {
                recheckSavedSpeaker(reason: "discovery found nothing")
                return .notFound
            }
            saveSpeaker(updated)
            switch ConnectionAfterDiscovery(foundIP: updated.lastKnownIp, connectedIP: connection?.host) {
            case .keep: recheckLiveConnection(reason: "discovery found the speaker where it is connected")
            case .reconnect: reconnect(.afterDiscovery, reason: "discovery found the speaker")
            }
            return .found(updated)
        } catch {
            logger.error("Discovery failed: \(error)")
            recheckSavedSpeaker(reason: "discovery failed")
            // Name the setting until the recheck, if any, gives a live answer.
            if LocalNetworkPermission.isDenied(by: error) {
                menuBar.set(.localNetworkBlocked, reason: "discovery failed: \(error)")
            }
            return .failure(error)
        }
    }

    /// Keep the live connection and check it again, so the menu bar leaves
    /// "Searching" with a live answer.
    private func recheckLiveConnection(reason: String) {
        guard let controller, let connection else { return }
        logger.info("Keeping the connection to \(connection.host): \(reason)")
        menuBar.set(.connecting, reason: reason)
        checkSpeaker(controller, on: connection, origin: .afterDiscovery)
    }

    /// After discovery finds nothing, check the saved IP again, so the menu
    /// bar shows a live answer rather than a guess. With no IP saved, only
    /// show that: connecting would start discovery again.
    private func recheckSavedSpeaker(reason: String) {
        let idle = ConnectionStatus.idle(isActive: isActive, speakerIP: config.speaker?.lastKnownIp)
        if idle == .connecting {
            reconnect(.afterDiscovery, reason: reason)
        } else {
            menuBar.set(idle, reason: reason)
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
        saveConfig(what: "speaker at \(speaker.lastKnownIp ?? "unknown IP")")
    }

    /// Use Auto or Manual discovery from now on, and save it. Switching to
    /// Auto while the speaker isn't answering looks for it straight away.
    private func applyDiscovery(_ mode: DiscoveryMode) {
        guard mode != config.discovery else { return }
        logger.info("Discovery mode \(config.discovery.rawValue) -> \(mode.rawValue)")
        config.discovery = mode
        saveConfig(what: "discovery mode \(mode.rawValue)")
        if mode.searchesBySelf, isActive, menuBar.status != .connected {
            discoverInBackground(trigger: "switched to Auto discovery")
        }
    }

    private func saveConfig(what: String) {
        do {
            try AppConfig.save(config, to: configFileURL)
            logger.info("Saved \(what)")
        } catch {
            logger.error("Could not save config: \(error.localizedDescription)")
        }
    }

    // MARK: - Command results

    /// The speaker controller, or nil with a log line saying the command
    /// was skipped (no IP yet, off the home network, or reconnecting).
    private func controller(for command: String) -> SpeakerController? {
        guard let controller else {
            logger.warning("Skipped \(command): no speaker connection")
            return nil
        }
        return controller
    }

    // MARK: - Volume commands

    /// How many percent one volume key press moves the speaker.
    private static let volumeStep = 5

    private func setupMediaKeyCallbacks() {
        mediaKeys.onMediaKey = { [weak self] action in
            self?.runVolumeCommand(action)
        }
    }

    /// Volume up, down or mute: from a modifier + media key, or from a
    /// recorded shortcut. The HUD shows the new level, or Muted.
    private func runVolumeCommand(_ action: MediaKeyInterceptor.MediaKeyAction) {
        guard let controller = controller(for: "\(action)") else { return }

        Task {
            do {
                switch action {
                case .volumeUp:
                    try await controller.raiseVolume(by: Self.volumeStep)
                case .volumeDown:
                    try await controller.lowerVolume(by: Self.volumeStep)
                case .mute:
                    try await controller.toggleMute()
                }
                let state = try await controller.getVolumeState()
                // Volume keys show the level even while muted; mute shows which way it went.
                HUDOverlay.show(action == .mute && state.isMuted ? .muted : .volume(level: state.level))
            } catch {
                logger.error("Volume command failed: \(error.localizedDescription)")
                HUDOverlay.show(.error("Command failed"))
                handleCommandError(error)
            }
        }
    }

    // MARK: - Shortcuts

    /// Turn each shortcut press into a command, and start listening. The
    /// shortcuts stay off until ``activate()`` (on the home network).
    private func setupShortcuts() {
        shortcuts.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .powerToggle: self.togglePower()
            case .volumeUp: self.runVolumeCommand(.volumeUp)
            case .volumeDown: self.runVolumeCommand(.volumeDown)
            case .mute: self.runVolumeCommand(.mute)
            case .quit: NSApplication.shared.terminate(nil)
            }
        }
        shortcuts.listen()
        shortcuts.setEnabled(false, reason: "until on the home network")
    }

    /// Read whether the speaker is on, then flip it. The HUD shows which
    /// way it went.
    private func togglePower() {
        guard let controller = controller(for: "power toggle") else { return }

        Task {
            do {
                let isOn = try await controller.togglePower()
                HUDOverlay.show(isOn ? .powerOn : .powerOff)
            } catch {
                logger.error("Power toggle failed: \(error.localizedDescription)")
                HUDOverlay.show(.error("Power failed"))
                handleCommandError(error)
            }
        }
    }

    // MARK: - Lifecycle callbacks

    private func setupLifecycleCallbacks() {
        lifecycle.onWake = { [weak self] in
            guard let self, self.config.lifecycle.powerOnWake else { return }
            guard let controller = self.controller(for: "wake power-on") else { return }

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
                    self.handleCommandError(error)
                }
            }
        }

        lifecycle.onSleep = { [weak self] in
            guard let self, self.config.lifecycle.powerOffSleep else { return }
            guard let controller = self.controller(for: "sleep power-off") else { return }

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
            guard let self, let controller = self.controller(for: "standby \(mode)") else { return }

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
    /// If the speaker could not be reached, it may have a new IP, so in
    /// Auto discovery run discovery (which saves the new IP and reconnects).
    /// Otherwise disconnect and reconnect to the same IP after 2 seconds.
    private func handleCommandError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let kefError = error as? KEFError, kefError.isConnectionFailure, self.config.discovery.searchesBySelf {
                self.rediscover(reason: "\(kefError)")
                return
            }

            self.disconnectSpeaker()
            self.logger.info("Command error — disconnecting and reconnecting in 2s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.isActive else { return }
                self.logger.info("Reconnecting to speaker")
                self.connectToSpeaker(.savedIP)
            }
        }
    }
}
