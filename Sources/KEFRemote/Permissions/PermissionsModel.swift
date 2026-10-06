import AppKit
import Combine
import KEFRemoteCore

/// What the permissions guide shows: whether KEF Remote has Accessibility
/// and Local Network, as far as it can tell (see ``PermissionStatus``).
///
/// `AppDelegate` owns it and feeds it the connection status. It checks
/// Accessibility again every few seconds for the menu bar, and every
/// second while the guide window is open. Each change and click is
/// logged once, under `permissions`:
///
/// ```
/// [permissions] accessibility notGranted at launch
/// [permissions] checking accessibility every 3.0 seconds for the menu bar
/// [permissions] Accessibility: Open Settings clicked, opened x-apple.systempreferences:…
/// [permissions] accessibility notGranted -> granted (guide open)
/// [permissions] local network notCheckedYet -> granted (connection connected)
/// [permissions] local network notGranted -> granted (probe)
/// [permissions] I've allowed it clicked: blocked, showing "Checked: still blocked. …"
/// [permissions] volume key tap notStarted -> running: "Volume keys ready ✓"
/// [permissions] volume key tap notStarted -> refused: offering Restart KEF Remote
/// [permissions] Accessibility allowed during this run: setup step 1 offers Restart and continue
/// ```
@MainActor
final class PermissionsModel: ObservableObject {
    @Published private(set) var accessibility: PermissionStatus
    @Published private(set) var localNetwork: PermissionStatus = .notCheckedYet
    /// Whether the volume key tap is on, as the app last started or
    /// stopped it: the guide's ``volumeKeysLine`` says so.
    @Published private(set) var mediaKeyTap: MediaKeyTapState = .notStarted
    /// Which permissions he switched on while this copy runs: setup step 1
    /// then offers Restart and continue (``PermissionsStepContinue``).
    @Published private(set) var grantedThisRun = PermissionsGrantedThisRun()

    /// What the last I've allowed it click found, under the Local Network
    /// row (``LocalNetworkProbe/Result/checkLine``). Nil until clicked.
    @Published private(set) var localNetworkCheckLine: String?

    /// Called when Accessibility is switched on while the app runs, so
    /// the volume keys can start without a restart.
    var onAccessibilityGranted: (() -> Void)?

    /// Asks macOS about Local Network now, for I've allowed it. The app
    /// fills it in: it owns the probe, and tries the speaker if blocked.
    var checkLocalNetworkNow: (() -> LocalNetworkProbe.Result)?

    /// The system prompt is shown once a run: after that, macOS adds
    /// nothing new, and the pane is what he needs.
    private var hasAskedForAccessibility = false

    /// The slow check that keeps the menu bar's red dot true.
    private var accessibilityWatch: Task<Void, Never>?

    private let log = AppLogger(subsystem: "com.kef-remote", category: "permissions")

    init() {
        accessibility = PermissionStatus(accessibilityTrusted: MediaKeyInterceptor.checkAccessibility())
        log.info("accessibility \(accessibility.rawValue) at launch")
    }

    var rows: [PermissionRow] {
        PermissionsGuide.rows(accessibility: accessibility, localNetwork: localNetwork)
    }

    /// Ask macOS again, without a prompt. Logs only a change.
    func checkAccessibility(reason: String) {
        let checked = PermissionStatus(accessibilityTrusted: MediaKeyInterceptor.checkAccessibility())
        guard checked != accessibility else { return }
        let old = accessibility
        accessibility = checked
        log.info("accessibility \(old.rawValue) -> \(checked.rawValue) (\(reason))")
        noteGrant(.accessibility, from: old, to: checked)
        if PermissionStatus.isNewlyGranted(from: old, to: checked) {
            onAccessibilityGranted?()
        }
    }

    /// macOS sends no notification when Accessibility changes, so ask
    /// every ``PermissionsGuide/menuBarRecheckInterval`` while the app
    /// runs: the menu bar's red dot then follows System Settings even
    /// with the guide closed. Logs once here; each check logs only a change.
    func watchAccessibility() {
        guard accessibilityWatch == nil else { return }
        log.info("checking accessibility every \(PermissionsGuide.menuBarRecheckInterval) for the menu bar")
        accessibilityWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: PermissionsGuide.menuBarRecheckInterval)
                guard !Task.isCancelled else { return }
                self?.checkAccessibility(reason: "menu bar check")
            }
        }
    }

    /// Once Accessibility is allowed: Volume keys ready ✓, or Restart KEF
    /// Remote if macOS still refuses the tap (``VolumeKeysLine``).
    var volumeKeysLine: VolumeKeysLine? {
        VolumeKeysLine(accessibility: accessibility, tap: mediaKeyTap)
    }

    /// Show the volume key tap as the app just started or stopped it.
    /// Logs only a change, with the line the guide now shows.
    func showMediaKeyTap(_ tap: MediaKeyTapState) {
        guard tap != mediaKeyTap else { return }
        let old = mediaKeyTap
        mediaKeyTap = tap
        let shown = volumeKeysLine.map { "\"\($0.text)\"" } ?? "no line (Accessibility not allowed)"
        if volumeKeysLine == .needsRestart {
            log.warning("volume key tap \(old.rawValue) -> \(tap.rawValue): offering Restart KEF Remote")
        } else {
            log.info("volume key tap \(old.rawValue) -> \(tap.rawValue): \(shown)")
        }
    }

    /// Read Local Network from the connection: a reply means allowed,
    /// a blocked error means not.
    func showConnection(_ status: ConnectionStatus) {
        let seen = localNetwork.localNetwork(after: status)
        guard seen != localNetwork else { return }
        log.info("local network \(localNetwork.rawValue) -> \(seen.rawValue) (connection \(status.rawValue))")
        noteGrant(.localNetwork, from: localNetwork, to: seen)
        localNetwork = seen
    }

    /// Read Local Network from a probe while it's blocked: a packet that
    /// got out means allowed, before the speaker has answered.
    func showProbe(_ result: LocalNetworkProbe.Result) {
        let seen = localNetwork.localNetwork(after: result)
        guard seen != localNetwork else { return }
        log.info("local network \(localNetwork.rawValue) -> \(seen.rawValue) (probe)")
        noteGrant(.localNetwork, from: localNetwork, to: seen)
        localNetwork = seen
    }

    /// I've allowed it on the Local Network row: ask macOS now, and say
    /// what it found under the row.
    func localNetworkCheckClicked() {
        guard let checkLocalNetworkNow else {
            log.error("I've allowed it clicked, but nothing can check Local Network")
            return
        }
        let result = checkLocalNetworkNow()
        localNetworkCheckLine = result.checkLine
        log.info("I've allowed it clicked: \(result), showing \"\(result.checkLine)\"")
    }

    /// Count a permission he switched on during this run, logging it once.
    private func noteGrant(_ permission: Permission, from old: PermissionStatus, to new: PermissionStatus) {
        guard grantedThisRun.note(permission, from: old, to: new) else { return }
        log.info("\(permission.title) allowed during this run: setup step 1 offers Restart and continue")
    }

    /// Open the permission's pane in System Settings. For Accessibility,
    /// the first click also asks macOS, which adds KEF Remote to the list
    /// so he only has to switch it on: asking is the only call that adds
    /// it; otherwise he'd have to find the app with + himself. The prompt
    /// is a system dialog, so the app's windows stay back while it's up
    /// (``WindowFront``; hand test round 7, where the Mac stopped taking
    /// clicks during this step).
    func openSettings(for permission: Permission) {
        if permission == .accessibility && !hasAskedForAccessibility {
            hasAskedForAccessibility = true
            AgentWindowPresenter.systemPromptShown()
            let trusted = MediaKeyInterceptor.checkAccessibility(prompt: true)
            log.info(
                "asked macOS for Accessibility (system prompt, once a run): trusted=\(trusted); "
                + "windows stay back for \(WindowFront.holdBackAfterSystemPrompt)"
            )
        }
        let url = permission.settingsURL
        if NSWorkspace.shared.open(url) {
            log.info("\(permission.title): Open Settings clicked, opened \(url.absoluteString)")
        } else {
            log.error("\(permission.title): Open Settings clicked, could not open \(url.absoluteString)")
        }
    }
}
