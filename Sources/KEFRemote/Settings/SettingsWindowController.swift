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
/// settings shown: visible=true key=true appActive=true policy=accessory
/// ```
/// If `appActive` is false after the first try, the app shows a Dock
/// icon while the window is open, and logs `policy accessory -> regular`.
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
    private var window: NSWindow?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")
    private lazy var presenter = AgentWindowPresenter(name: "settings", log: log)

    init(model: SettingsModel, menuBar: MenuBarModel) {
        self.model = model
        self.menuBar = menuBar
    }

    func show(source: Source) {
        log.info("settings open requested (source: \(source.rawValue))")
        presenter.show(window ?? makeWindow())
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model, menuBar: menuBar)))
        window.title = "KEF Remote Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        log.info("settings window created")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        log.info("settings closed")
        presenter.windowClosed()
    }
}
