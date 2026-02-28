import AppKit
import os

/// Manages the app lifecycle for KEF Remote.
///
/// Key responsibilities:
/// - Sets the activation policy to `.accessory` so the app runs as a
///   background agent with no dock icon and no menu bar presence.
/// - Detects re-launch attempts and handles them by opening the settings
///   window (placeholder logging for now — the settings window is added
///   in a later task).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: "com.kef-remote",
        category: "AppDelegate"
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background agent: no dock icon, no menu bar.
        // This is the programmatic equivalent of LSUIElement = true
        // in Info.plist, and works reliably with SPM executables.
        NSApp.setActivationPolicy(.accessory)

        logger.info("KEF Remote launched as background agent")
    }

    /// Called when the user re-launches the app while it is already running
    /// (e.g. double-clicking the app icon again, or running from terminal).
    ///
    /// For now this just logs the event. Once the settings window is
    /// implemented (Task 21), this will open it.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        logger.info("Re-launch detected — will open settings (not yet implemented)")
        // TODO: Task 21 — open the settings window here
        return true
    }
}
