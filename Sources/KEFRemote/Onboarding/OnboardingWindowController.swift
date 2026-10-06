import AppKit
import KEFRemoteCore
import SwiftUI

/// Opens the setup window: a plain `NSWindow` hosting ``OnboardingView``,
/// like the settings window. All three steps until setup is finished (at
/// launch, from Finish setup… in the menu, or the Dock icon); step 1 on
/// its own (the permissions guide) from Permissions…, or at a later
/// launch while Accessibility is missing. ``SetupWindowOpening`` says
/// which, and the step it opens on.
///
/// While it's open, it asks macOS about Accessibility every
/// ``PermissionsGuide/recheckInterval``, so the tick appears soon after
/// he switches it on. It stops asking when the window closes.
///
/// Logged under `onboarding`:
/// ```
/// window opened (source: launch, resumeAllSteps): accessibility notGranted, local network notCheckedYet
/// setup opened: Dock icon on (policy accessory -> regular)
/// setup shown: visible=true key=true appActive=true policy=regular
/// window closed on step 2 Find your speaker
/// ```
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {

    enum Source: String {
        /// At launch: setup isn't finished, or Accessibility is missing.
        case launch
        /// Finish setup… or Permissions… in the menu bar menu.
        case menu
        /// The Dock icon, or the app opened again while it runs.
        case reopen
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

    /// Whether the window is open on all the steps, for Permissions…
    /// (``Onboarding/permissionsItemOpens(isFinished:allStepsShowing:)``).
    var isShowingAllSteps: Bool {
        window?.isVisible == true && model.mode == .allSteps
    }

    func show(_ opening: SetupWindowOpening, source: Source) {
        model.permissions.checkAccessibility(reason: "window opened")
        model.open(opening)
        log.info(
            "window opened (source: \(source.rawValue), \(opening.rawValue)): "
            + "accessibility \(model.permissions.accessibility.rawValue), "
            + "local network \(model.permissions.localNetwork.rawValue)"
        )
        let window = window ?? makeWindow()
        window.title = model.mode == .allSteps ? "Set up KEF Remote" : "KEF Remote Permissions"
        presenter.show(window)
        startRechecking()
    }

    private func makeWindow() -> NSWindow {
        let window = AgentWindowPresenter.makeWindow(
            NSHostingController(rootView: OnboardingView(
                model: model,
                permissions: model.permissions,
                settings: model.settings,
                menuBar: model.menuBar
            )),
            delegate: self
        )
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
