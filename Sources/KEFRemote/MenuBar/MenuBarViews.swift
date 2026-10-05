import AppKit
import SwiftUI

/// The menu bar icon. Its shape shows the last command's result.
struct MenuBarIcon: View {
    @ObservedObject var model: MenuBarModel

    var body: some View {
        let shown = model.presentation
        Image(systemName: shown.symbolName)
            .accessibilityLabel(shown.accessibilityLabel)
    }
}

/// The menu that drops down from the icon.
///
/// ```
/// Connected to LSX      (status line, disabled)
/// ─────────────
/// Settings…        ⌘,
/// Quit KEF Remote  ⌘Q
/// ```
struct MenuBarMenu: View {
    @ObservedObject var model: MenuBarModel
    let openSettings: () -> Void

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var body: some View {
        Text(model.presentation.title)

        Divider()

        Button("Settings…") {
            log.info("menu: Settings… clicked")
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit KEF Remote") {
            log.info("menu: Quit clicked")
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
