import SwiftUI

/// The main entry point for the KEF Remote macOS app.
///
/// The app runs as a background agent (no Dock icon). Its only scene is
/// a menu bar icon with a small menu: whether it is connected, Find
/// speaker when it isn't, Permissions…, Settings…, a link to who made
/// it, and Quit.
/// The settings window is a plain `NSWindow` owned by ``AppDelegate``
/// (see ``SettingsWindowController``), so it can open from the menu and
/// when the app is launched again while it is running. The permissions
/// guide is one too (``PermissionsWindowController``), so it can open at
/// launch.
///
/// Removing the icon from the menu bar (Cmd-drag) quits the app.
@main
struct KEFRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(
                model: appDelegate.menuBar,
                permissions: appDelegate.permissions,
                findSpeaker: { appDelegate.findSpeaker() },
                openPermissions: { appDelegate.showPermissions(source: .menu) },
                openSettings: { appDelegate.showSettings(source: .menu) }
            )
        } label: {
            MenuBarIcon(model: appDelegate.menuBar, pulse: appDelegate.menuBar.pulse)
        }
        .menuBarExtraStyle(.menu)
    }
}
