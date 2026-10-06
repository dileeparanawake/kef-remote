import AppKit
import KEFRemoteCore
import SwiftUI

/// Opens the permissions guide: a plain `NSWindow` hosting
/// ``PermissionsView``, like the settings window.
///
/// While it's open, it asks macOS about Accessibility every
/// ``PermissionsGuide/recheckInterval``, so the tick appears soon after
/// he switches it on. It stops asking when the window closes.
///
/// Logged under `permissions`:
/// ```
/// guide opened (source: launch): accessibility notGranted, local network notCheckedYet
/// guide shown: visible=true key=true appActive=true policy=accessory
/// guide closed
/// ```
@MainActor
final class PermissionsWindowController: NSObject, NSWindowDelegate {

    enum Source: String {
        /// At launch, because Accessibility is missing.
        case launch
        /// Permissions… in the menu bar menu.
        case menu
    }

    private let model: PermissionsModel
    private var window: NSWindow?
    private var recheck: Task<Void, Never>?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "permissions")
    private lazy var presenter = AgentWindowPresenter(name: "guide", log: log)

    init(model: PermissionsModel) {
        self.model = model
    }

    func show(source: Source) {
        model.checkAccessibility(reason: "guide opened")
        log.info(
            "guide opened (source: \(source.rawValue)): accessibility \(model.accessibility.rawValue), "
            + "local network \(model.localNetwork.rawValue)"
        )
        presenter.show(window ?? makeWindow())
        startRechecking()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PermissionsView(model: model)))
        window.title = "KEF Remote Permissions"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }

    /// macOS sends no notification when Accessibility changes, so ask.
    private func startRechecking() {
        guard recheck == nil else { return }
        recheck = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: PermissionsGuide.recheckInterval)
                guard !Task.isCancelled else { return }
                self?.model.checkAccessibility(reason: "guide open")
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        recheck?.cancel()
        recheck = nil
        log.info("guide closed")
        presenter.windowClosed()
    }
}
