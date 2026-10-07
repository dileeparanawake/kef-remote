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
/// Windows stay at the normal level. For a few seconds after the macOS
/// Accessibility prompt, none is pulled over it, and a window that
/// didn't come to the front tries again only twice (``WindowFront``).
///
/// Logged under the caller's category:
/// ```
/// setup opened: Dock icon on (policy accessory -> regular)
/// setup shown: visible=true key=true appActive=true policy=regular
/// setup not in front: trying again (1 of 2)
/// setup not in front after 2 tries: leaving it (its Dock icon brings it back)
/// setup not in front: not pulling it over the macOS prompt
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

    /// When the app last showed the macOS Accessibility prompt. For a
    /// while after it, no window is pulled over it (``WindowFront``).
    private static var systemPromptAt: ContinuousClock.Instant?

    /// The macOS Accessibility prompt is up: hold every window back.
    static func systemPromptShown() {
        systemPromptAt = .now
    }

    private static var mayPullToFront: Bool {
        WindowFront.mayPullToFront(now: .now, systemPromptAt: systemPromptAt)
    }

    func show(_ window: NSWindow) {
        if Self.openWindows.opened(name) == .show {
            NSApp.setActivationPolicy(.regular)
            log.info("\(name) opened: Dock icon on (policy accessory -> regular)")
        }
        if Self.mayPullToFront {
            bringToFront(window)
        } else {
            // Shown, but not over the macOS prompt: it comes forward
            // when he clicks it or its Dock icon.
            window.orderFront(nil)
            log.info("\(name) shown without coming to the front: the macOS prompt is up")
        }
        checkInFront(window, triesSoFar: 0)
    }

    /// Activation is asynchronous, so look a moment later, and try again
    /// a set number of times (``WindowFront``).
    private func checkInFront(_ window: NSWindow, triesSoFar: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationCheckDelay) {
            if triesSoFar == 0 { logShown(window) }
            guard window.isVisible else { return }
            let check = WindowFront.afterCheck(
                isInFront: NSApp.isActive, triesSoFar: triesSoFar, mayPull: Self.mayPullToFront
            )
            if let line = check.logLine(window: name) { log.info(line) }
            guard case .tryAgain(let tries) = check else { return }
            bringToFront(window)
            checkInFront(window, triesSoFar: tries)
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
