import AppKit

/// Brings one of the app's own windows to the front, and tidies up when
/// it closes. Used by the settings window and the permissions guide.
///
/// An agent app (no Dock icon) can be refused activation, so its window
/// opens behind others. If that happens, the app shows a Dock icon
/// (regular policy) while the window is open, and tries again.
///
/// Logged under the caller's category:
/// ```
/// settings shown: visible=true key=true appActive=true policy=accessory
/// app did not come to the front: policy accessory -> regular
/// policy regular -> accessory      (on close)
/// ```
@MainActor
struct AgentWindowPresenter {
    /// Names the window in the log, e.g. "settings".
    let name: String
    let log: AppLogger

    /// Activation is asynchronous: long enough for it to land.
    private static let activationCheckDelay: TimeInterval = 0.3

    func show(_ window: NSWindow) {
        bringToFront(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) {
            logShown(window)
            guard !NSApp.isActive, NSApp.activationPolicy() == .accessory else { return }
            log.info("app did not come to the front: policy accessory -> regular")
            NSApp.setActivationPolicy(.regular)
            bringToFront(window)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) {
                logShown(window)
            }
        }
    }

    /// Call from `windowWillClose`: takes the Dock icon away again.
    func windowClosed() {
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
            log.info("policy regular -> accessory")
        }
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func logShown(_ window: NSWindow) {
        log.info(
            "\(name) shown: visible=\(window.isVisible) key=\(window.isKeyWindow) "
            + "appActive=\(NSApp.isActive) policy=\(Self.describe(NSApp.activationPolicy()))"
        )
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
