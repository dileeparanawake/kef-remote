import AppKit

/// Quits KEF Remote and opens it again, for Restart KEF Remote in the
/// permissions guide: a new process gets the volume key tap that macOS
/// refused this one.
///
/// A shell waits ``openDelay`` then opens the app bundle as a new
/// instance (`open -n`), while this one quits. The wait lets this one
/// quit first, so two menu bar icons never show at once.
enum AppRelauncher {
    /// Long enough for this copy to quit.
    static let openDelay = "1"

    static func relaunch(log: AppLogger) {
        let bundlePath = Bundle.main.bundlePath
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The path goes in as $1, so a space in it needs no quoting here.
        shell.arguments = ["-c", "sleep \(openDelay); /usr/bin/open -n \"$1\"", "relaunch", bundlePath]
        do {
            try shell.run()
            log.info("restarting: opening \(bundlePath) again in \(openDelay) s, quitting this one")
            NSApp.terminate(nil)
        } catch {
            log.error("could not restart: \(error.localizedDescription)")
        }
    }
}
