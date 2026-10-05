import AppKit
import SwiftUI

/// The menu bar icon. Filled speaker when connected; other shapes say
/// why not, and a red dot says something needs him (see
/// ``MenuBarPresentation`` and ``MenuBarIconImage``).
struct MenuBarIcon: View {
    @ObservedObject var model: MenuBarModel
    /// Read so the icon is drawn again when light or dark mode changes.
    @Environment(\.colorScheme) private var colorScheme

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var body: some View {
        let shown = model.presentation
        Image(nsImage: MenuBarIconImage.make(
            symbolName: shown.symbolName,
            dot: shown.dot,
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
/// Connected to LSX          Can't reach LSX: click Find speaker
/// 192.168.1.80              No answer at 192.168.1.80
/// ─────────────             Find speaker
/// Settings…        ⌘,       ─────────────
/// Quit KEF Remote  ⌘Q       Settings… / Quit
/// ```
struct MenuBarMenu: View {
    @ObservedObject var model: MenuBarModel
    let findSpeaker: () -> Void
    let openSettings: () -> Void

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
