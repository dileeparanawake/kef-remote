import AppKit
import Combine
import KEFRemoteCore

/// What the permissions guide shows: whether KEF Remote has Accessibility
/// and Local Network, as far as it can tell (see ``PermissionStatus``).
///
/// `AppDelegate` owns it and feeds it the connection status; the guide
/// window asks it to check Accessibility again while open. Each change
/// and click is logged once, under `permissions`:
///
/// ```
/// [permissions] accessibility notGranted at launch
/// [permissions] Accessibility: Open Settings clicked, opened x-apple.systempreferences:…
/// [permissions] accessibility notGranted -> granted (guide open)
/// [permissions] local network notCheckedYet -> granted (connection connected)
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

    /// Read Local Network from the connection: a reply means allowed,
    /// a blocked error means not.
    func showConnection(_ status: ConnectionStatus) {
        let seen = localNetwork.localNetwork(after: status)
        guard seen != localNetwork else { return }
        log.info("local network \(localNetwork.rawValue) -> \(seen.rawValue) (connection \(status.rawValue))")
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
