import AppKit
import KEFRemoteCore
import SwiftUI

/// Opens the setup window: a plain `NSWindow` hosting ``OnboardingView``,
/// like the settings window. All three steps the first time; step 1 on
/// its own (the permissions guide) from Permissions… in the menu, or at
/// a later launch while Accessibility is missing.
///
/// While it's open, it asks macOS about Accessibility every
/// ``PermissionsGuide/recheckInterval``, so the tick appears soon after
/// he switches it on. It stops asking when the window closes.
///
/// Logged under `onboarding`:
/// ```
/// window opened (source: launch, allSteps): accessibility notGranted, local network notCheckedYet
/// setup shown: visible=true key=true appActive=true policy=accessory
/// window closed on step 2 Find your speaker
/// ```
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {

    enum Source: String {
        /// At launch: setup isn't finished, or Accessibility is missing.
        case launch
        /// Permissions… in the menu bar menu.
        case menu
    }

    private let model: OnboardingModel
    private var window: NSWindow?
    private var recheck: Task<Void, Never>?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "onboarding")
    private lazy var presenter = AgentWindowPresenter(name: "setup", log: log)

    init(model: OnboardingModel) {
        self.model = model
        super.init()
        model.onClose = { [weak self] in self?.window?.close() }
    }

    /// Open in `mode`. Permissions… while setup is open goes back to its
    /// step 1, rather than dropping the steps he's part-way through.
    func show(_ mode: OnboardingMode, source: Source) {
        model.permissions.checkAccessibility(reason: "window opened")
        if let window, window.isVisible, model.mode == .allSteps {
            model.go(to: .permissions)
        } else {
            model.open(mode)
        }
        log.info(
            "window opened (source: \(source.rawValue), \(model.mode.rawValue)): "
            + "accessibility \(model.permissions.accessibility.rawValue), "
            + "local network \(model.permissions.localNetwork.rawValue)"
        )
        let window = window ?? makeWindow()
        window.title = model.mode == .allSteps ? "Set up KEF Remote" : "KEF Remote Permissions"
        presenter.show(window)
        startRechecking()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(
            model: model,
            permissions: model.permissions,
            settings: model.settings,
            menuBar: model.menuBar
        )))
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
                self?.model.permissions.checkAccessibility(reason: "window open")
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        recheck?.cancel()
        recheck = nil
        log.info("window closed on step \(model.step.number) \(model.step.title)")
        presenter.windowClosed()
    }
}
