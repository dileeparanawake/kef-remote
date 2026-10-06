import AppKit
import SwiftUI

/// Opens the settings window: a plain `NSWindow` hosting ``SettingsView``.
///
/// The SwiftUI `Settings` scene can only be opened from inside a SwiftUI
/// view, and does not bring an agent app to the front. A window we own
/// can be shown from anywhere (see ``AgentWindowPresenter``).
///
/// Logged under `menubar`:
/// ```
/// settings open requested (source: menu)
/// settings window created            (once per run)
/// settings opened: Dock icon on (policy accessory -> regular)
/// settings shown: visible=true key=true appActive=true policy=regular
/// ```
/// The app shows a Dock icon while the window is open, so it can be
/// found again behind other apps' windows.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    enum Source: String {
        /// Settings… in the menu bar menu.
        case menu
        /// The app was launched again while running.
        case reopen
    }

    private let model: SettingsModel
    private let menuBar: MenuBarModel
    /// Send feedback… in the About tab.
    private let sendFeedback: () -> Void
    private var window: NSWindow?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")
    private lazy var presenter = AgentWindowPresenter(name: "settings", log: log)

    init(model: SettingsModel, menuBar: MenuBarModel, sendFeedback: @escaping () -> Void) {
        self.model = model
        self.menuBar = menuBar
        self.sendFeedback = sendFeedback
    }

    func show(source: Source) {
        log.info("settings open requested (source: \(source.rawValue))")
        presenter.show(window ?? makeWindow())
    }

    private func makeWindow() -> NSWindow {
        let window = AgentWindowPresenter.makeWindow(
            NSHostingController(rootView: SettingsView(model: model, menuBar: menuBar, sendFeedback: sendFeedback)),
            delegate: self
        )
        window.title = "KEF Remote Settings"
        self.window = window
        log.info("settings window created")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        log.info("settings closed")
        presenter.windowClosed()
    }
}
