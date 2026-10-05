import AppKit
import SwiftUI

/// Opens the settings window: a plain `NSWindow` hosting ``SettingsView``.
///
/// The SwiftUI `Settings` scene can only be opened from inside a SwiftUI
/// view, and does not bring an agent app to the front. A window we own
/// can be shown from anywhere, with three AppKit calls.
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
    private var window: NSWindow?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")
    private static let activationCheckDelay: TimeInterval = 0.3

    init(model: SettingsModel) {
        self.model = model
    }

    func show(source: Source) {
        log.info("settings open requested (source: \(source.rawValue))")
        let window = self.window ?? makeWindow()
        bringToFront(window)

        // Activation is asynchronous, so check a moment later. An agent
        // app's activation can be refused; showing a Dock icon (regular
        // policy) while the window is open gives it a second chance.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) { [self] in
            logShown(window)
            guard !NSApp.isActive, NSApp.activationPolicy() == .accessory else { return }
            log.info("app did not come to the front: policy accessory -> regular")
            NSApp.setActivationPolicy(.regular)
            bringToFront(window)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) { [self] in
                logShown(window)
            }
        }
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func logShown(_ window: NSWindow) {
        log.info(
            "settings shown: visible=\(window.isVisible) key=\(window.isKeyWindow) "
            + "appActive=\(NSApp.isActive) policy=\(Self.describe(NSApp.activationPolicy()))"
        )
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
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
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
            log.info("policy regular -> accessory")
        }
    }

    private static func describe(_ policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "unknown"
        }
    }
}
