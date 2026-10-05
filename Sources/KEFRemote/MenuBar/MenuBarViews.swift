import AppKit
import SwiftUI

/// The menu bar icon. Filled speaker when connected; other shapes say
/// why not (see ``MenuBarPresentation``).
struct MenuBarIcon: View {
    @ObservedObject var model: MenuBarModel

    /// SF Symbol point size. At 13pt the speaker symbols are 16 to 17pt
    /// tall, the size of the system's own menu bar icons.
    private static let symbolPointSize: CGFloat = 13

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var body: some View {
        let shown = model.presentation
        Image(nsImage: Self.templateImage(shown.symbolName))
            .accessibilityLabel(shown.accessibilityLabel)
            .onAppear { log.info("menu bar icon shown: \(shown.symbolName)") }
    }

    /// A fixed-size template image, so macOS tints it for light and dark
    /// menu bars and it never grows past the bar.
    private static func templateImage(_ symbolName: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// The menu that drops down from the icon.
///
/// ```
/// Connected to LSX          Not connected
/// 192.168.1.80              Can't reach LSX at 192.168.1.80
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
