import AppKit
import KEFRemoteCore
import SwiftUI

/// The menu bar icon. Filled speaker when connected; other shapes say
/// why not, and a red dot says something needs him (see
/// ``MenuBarPresentation`` and ``MenuBarIconImage``). An orange dot
/// pulses while it looks for the speaker (``MenuBarPulse``).
struct MenuBarIcon: View {
    @ObservedObject var model: MenuBarModel
    /// Watched here, not through the model, so each pulse frame redraws
    /// only the icon.
    @ObservedObject var pulse: MenuBarPulse
    /// Read so the icon is drawn again when light or dark mode changes.
    @Environment(\.colorScheme) private var colorScheme

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var body: some View {
        let shown = model.presentation
        Image(nsImage: MenuBarIconImage.make(
            symbolName: shown.symbolName,
            dot: shown.dot,
            dotOpacity: shown.dot.pulses ? pulse.dotOpacity : 1,
            accessibilityLabel: shown.accessibilityLabel
        ))
        .accessibilityLabel(shown.accessibilityLabel)
        .onAppear { log.info("menu bar icon shown: \(shown.symbolName), dot \(shown.dot)") }
        .onChange(of: colorScheme) { _, scheme in log.info("menu bar icon redrawn for \(scheme) mode") }
    }
}

/// The menu that drops down from the icon.
///
/// ```
/// Connected to LSX          Volume keys off: allow Accessibility
/// 192.168.1.80              Click Permissions… to turn it on
/// ─────────────             ─────────────
/// Input        ▸            Input        ▸
/// ─────────────             ─────────────
/// Permissions… ✓            Permissions… (1 needs you)
/// Settings…        ⌘,       Settings…        ⌘,
/// ─────────────             ─────────────
/// Made by Dileepa ↗         Made by Dileepa ↗
/// Send feedback…            Send feedback…
/// ─────────────             ─────────────
/// Quit KEF Remote  ⌘Q       Quit KEF Remote  ⌘Q
/// ```
///
/// Find speaker shows under the first two lines when the speaker isn't
/// connected (``MenuBarPresentation/offersFindSpeaker``). The
/// Permissions… item says whether any permission needs him
/// (``PermissionsGuide/menuItemTitle(rows:)``). Input ▸ switches the
/// speaker's input now, ticked on the one it's on, and greyed out while the
/// speaker is off or not connected (``InputMenu``).
/// Support KEF Remote…
/// joins the links once its page exists (``MenuLink``), and Send feedback…
/// once its address is set (``FeedbackEmail``).
struct MenuBarMenu: View {
    @ObservedObject var model: MenuBarModel
    @ObservedObject var permissions: PermissionsModel
    let findSpeaker: () -> Void
    let switchInput: (InputSource) -> Void
    let openPermissions: () -> Void
    let openSettings: () -> Void
    let sendFeedback: () -> Void

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var body: some View {
        let shown = model.presentation

        Text(shown.title)
        Text(shown.detail)

        if shown.offersFindSpeaker {
            Button("Find speaker") {
                log.info("menu: Find speaker clicked")
                findSpeaker()
            }
        }

        Divider()

        let inputMenu = model.inputMenu
        Menu(InputMenu.title) {
            ForEach(inputMenu.items, id: \.input) { item in
                // A Toggle is how a SwiftUI menu item gets a tick. Picking
                // the ticked one switches again, which only shows the HUD.
                Toggle(item.title, isOn: Binding(
                    get: { item.isTicked },
                    set: { _ in
                        log.info("menu: Input \(item.title) clicked")
                        switchInput(item.input)
                    }
                ))
            }
        }
        .disabled(!inputMenu.isEnabled)

        Divider()

        let permissionsTitle = PermissionsGuide.menuItemTitle(rows: permissions.rows)
        Button(permissionsTitle) {
            log.info("menu: \(permissionsTitle) clicked")
            openPermissions()
        }

        Button("Settings…") {
            log.info("menu: Settings… clicked")
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        ForEach(MenuLink.shown, id: \.self) { link in
            Button(link.title) { open(link) }
        }

        if FeedbackEmail.isShown {
            Button(FeedbackEmail.menuTitle) {
                log.info("menu: \(FeedbackEmail.menuTitle) clicked")
                sendFeedback()
            }
        }

        Divider()

        Button("Quit KEF Remote") {
            log.info("menu: Quit clicked")
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func open(_ link: MenuLink) {
        guard let url = link.url else { return }
        let opened = NSWorkspace.shared.open(url)
        log.info("menu: \(link.title) clicked, \(opened ? "opened" : "could not open") \(url.absoluteString)")
    }
}
