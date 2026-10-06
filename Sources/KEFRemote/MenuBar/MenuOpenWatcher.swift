import AppKit

/// Fires ``onOpen`` each time the menu bar icon's menu opens.
///
/// SwiftUI gives no "menu opened" event for a `MenuBarExtra` in `.menu`
/// style: its content becomes an `NSMenu`, and `onAppear` there is not
/// promised to run again on each open. AppKit posts
/// `NSMenu.didBeginTrackingNotification` every time any menu starts
/// tracking, so this listens for that and keeps only our menu: a
/// top-level menu (not a submenu, not the app's main menu) that holds
/// ``MenuBarMenu/quitTitle``. Settings' pop-up pickers and Input ▸ are
/// left out that way. A menu left out logs at debug, so a hand test can
/// see if ours ever is:
/// ```
/// [menubar] menu tracking began: not the menu bar menu ("", 3 items)
/// ```
@MainActor
final class MenuOpenWatcher {
    var onOpen: (() -> Void)?

    private var observer: NSObjectProtocol?
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let menu = notification.object as? NSMenu else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                guard Self.isMenuBarMenu(menu) else {
                    self.log.debug("menu tracking began: not the menu bar menu (\"\(menu.title)\", \(menu.items.count) items)")
                    return
                }
                self.onOpen?()
            }
        }
    }

    private static func isMenuBarMenu(_ menu: NSMenu) -> Bool {
        menu.supermenu == nil
            && menu !== NSApp.mainMenu
            && menu.items.contains { $0.title == MenuBarMenu.quitTitle }
    }
}
