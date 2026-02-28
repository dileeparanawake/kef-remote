import SwiftUI

/// The main entry point for the KEF Remote macOS app.
///
/// This app runs as a background agent (no dock icon, no menu bar icon).
/// It uses an `AppDelegate` to manage lifecycle events including
/// single-instance detection and activation policy.
///
/// The `Settings` scene is a placeholder for the settings window
/// that will be added in a later task. It is not visible on launch.
@main
struct KEFRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("KEF Remote Settings")
                .frame(width: 300, height: 200)
        }
    }
}
