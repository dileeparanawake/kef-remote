import AppKit

/// Watches the app's menus open and close (`NSMenu` tracking), and fires:
///
/// - ``onAnyMenuBegan`` / ``onAnyMenuEnded`` for every menu the app
///   tracks: the menu bar menu, Settings' pop-up pickers, the app menu.
///   The global shortcuts go off meanwhile (``MenuTrackingShortcuts``).
/// - ``onOpen`` when the menu bar icon's menu opens, after
///   ``onAnyMenuBegan``.
///
/// SwiftUI gives no "menu opened" event for a `MenuBarExtra` in `.menu`
/// style: its content becomes an `NSMenu`, and `onAppear` there is not
/// promised to run again on each open. AppKit posts
/// `NSMenu.didBeginTrackingNotification` every time a menu starts
/// tracking, and `didEndTrackingNotification` when it stops, for the
/// top-level menu only (KeyboardShortcuts found the same). ``onOpen``
/// keeps only our menu: a top-level menu (not the app's main menu) that
/// holds ``MenuBarMenu/quitTitle``. Any other menu logs at debug, so a
/// hand test can see if ours ever is left out:
/// ```
/// [menubar] menu tracking began: not the menu bar menu ("", 3 items)
/// ```
@MainActor
final class MenuOpenWatcher {
    var onOpen: (() -> Void)?
    var onAnyMenuBegan: (() -> Void)?
    var onAnyMenuEnded: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let menu = notification.object as? NSMenu
            MainActor.assumeIsolated { self?.menuBegan(menu) }
        })
        observers.append(center.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onAnyMenuEnded?() }
        })
    }

    private func menuBegan(_ menu: NSMenu?) {
        onAnyMenuBegan?()
        guard let menu, Self.isMenuBarMenu(menu) else {
            log.debug("menu tracking began: not the menu bar menu (\"\(menu?.title ?? "")\", \(menu?.items.count ?? 0) items)")
            return
        }
        onOpen?()
    }

    private static func isMenuBarMenu(_ menu: NSMenu) -> Bool {
        menu.supermenu == nil
            && menu !== NSApp.mainMenu
            && menu.items.contains { $0.title == MenuBarMenu.quitTitle }
    }
}
