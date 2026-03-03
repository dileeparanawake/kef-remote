import SwiftUI

/// The main entry point for the KEF Remote macOS app.
///
/// This app runs as a background agent (no dock icon, no menu bar icon).
/// It uses an `AppDelegate` to manage lifecycle events including
/// single-instance detection and activation policy.
///
/// The `Settings` scene hosts the ``SettingsView``, which provides
/// configuration for speaker connection, hotkeys, audio defaults,
/// lifecycle behaviour, network awareness, and app preferences.
/// The settings window opens when the app is re-launched while
/// already running (see ``AppDelegate/applicationShouldHandleReopen(_:hasVisibleWindows:)``).
@main
struct KEFRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
