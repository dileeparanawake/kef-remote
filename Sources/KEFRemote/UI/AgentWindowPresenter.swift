import AppKit
import KEFRemoteCore

/// Makes and shows the app's own windows (settings, setup), and tidies
/// up when they close.
///
/// KEF Remote runs without a Dock icon. While any of these windows is
/// open it shows one (``OpenWindows``): then a window that goes behind
/// another app's can be found again in the Dock, Cmd-Tab and Mission
/// Control, like any app's window. Without it, the window seemed to
/// vanish (hand test round 3). A regular app is also refused activation
/// less often than an agent, so the window comes to the front.
///
/// Logged under the caller's category:
/// ```
/// setup opened: Dock icon on (policy accessory -> regular)
/// setup shown: visible=true key=true appActive=true policy=regular
/// setup not in front: trying again
/// setup closed: Dock icon off (policy regular -> accessory)
/// ```
@MainActor
struct AgentWindowPresenter {
    /// Names the window in the log, e.g. "settings".
    let name: String
    let log: AppLogger

    /// Shared by every presenter: the Dock icon stays while any is open.
    private static var openWindows = OpenWindows()

    /// Activation is asynchronous: long enough for it to land.
    private static let activationCheckDelay: TimeInterval = 0.3

    /// A plain window around `content`, centred on the screen.
    static func makeWindow(_ content: NSViewController, delegate: NSWindowDelegate) -> NSWindow {
        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        // SwiftUI sizes its content on the first layout. Centre after
        // that, or the window grows from a corner placed for a smaller
        // size and opens off to one side (hand test round 3).
        window.layoutIfNeeded()
        window.setContentSize(content.view.fittingSize)
        window.center()
        return window
    }

    func show(_ window: NSWindow) {
        if Self.openWindows.opened(name) == .show {
            NSApp.setActivationPolicy(.regular)
            log.info("\(name) opened: Dock icon on (policy accessory -> regular)")
        }
        bringToFront(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) {
            logShown(window)
            guard !NSApp.isActive, window.isVisible else { return }
            log.info("\(name) not in front: trying again")
            bringToFront(window)
        }
    }

    /// Call from `windowWillClose`: takes the Dock icon away once no
    /// window is left open.
    func windowClosed() {
        if Self.openWindows.closed(name) == .hide {
            NSApp.setActivationPolicy(.accessory)
            log.info("\(name) closed: Dock icon off (policy regular -> accessory)")
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
