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
/// ```
@MainActor
final class PermissionsModel: ObservableObject {
    @Published private(set) var accessibility: PermissionStatus
    @Published private(set) var localNetwork: PermissionStatus = .notCheckedYet

    /// Called when Accessibility is switched on while the app runs, so
    /// the volume keys can start without a restart.
    var onAccessibilityGranted: (() -> Void)?

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

    /// Read Local Network from the connection: a reply means allowed,
    /// a blocked error means not.
    func showConnection(_ status: ConnectionStatus) {
        let seen = localNetwork.localNetwork(after: status)
        guard seen != localNetwork else { return }
        log.info("local network \(localNetwork.rawValue) -> \(seen.rawValue) (connection \(status.rawValue))")
        localNetwork = seen
    }

    /// Read Local Network from a probe while it's blocked: a packet that
    /// got out means allowed, before the speaker has answered.
    func showProbe(_ result: LocalNetworkProbe.Result) {
        let seen = localNetwork.localNetwork(after: result)
        guard seen != localNetwork else { return }
        log.info("local network \(localNetwork.rawValue) -> \(seen.rawValue) (probe)")
        localNetwork = seen
    }

    /// Open the permission's pane in System Settings. For Accessibility,
    /// the first click also asks macOS, which adds KEF Remote to the list
    /// so he only has to switch it on.
    func openSettings(for permission: Permission) {
        if permission == .accessibility && !hasAskedForAccessibility {
            hasAskedForAccessibility = true
            let trusted = MediaKeyInterceptor.checkAccessibility(prompt: true)
            log.info("asked macOS for Accessibility (system prompt, once a run): trusted=\(trusted)")
        }
        let url = permission.settingsURL
        if NSWorkspace.shared.open(url) {
            log.info("\(permission.title): Open Settings clicked, opened \(url.absoluteString)")
        } else {
            log.error("\(permission.title): Open Settings clicked, could not open \(url.absoluteString)")
        }
    }
}
