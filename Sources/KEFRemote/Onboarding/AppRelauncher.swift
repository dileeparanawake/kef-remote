import AppKit

/// Quits KEF Remote and opens it again, for Restart KEF Remote in the
/// permissions guide and Restart and continue on setup step 1: a new
/// process gets the permissions allowed while this one ran, such as the
/// volume key tap that macOS refused this one.
///
/// A shell waits ``openDelay`` then opens the app bundle as a new
/// instance (`open -n`), while this one quits. The wait lets this one
/// quit first, so two menu bar icons never show at once.
enum AppRelauncher {
    /// Long enough for this copy to quit.
    static let openDelay = "1"

    /// - Returns: False if the new copy couldn't be started; this one
    ///   then keeps running.
    @discardableResult
    static func relaunch(log: AppLogger) -> Bool {
        let bundlePath = Bundle.main.bundlePath
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The path goes in as $1, so a space in it needs no quoting here.
        shell.arguments = ["-c", "sleep \(openDelay); /usr/bin/open -n \"$1\"", "relaunch", bundlePath]
        do {
            try shell.run()
            log.info("restarting: opening \(bundlePath) again in \(openDelay) s, quitting this one")
            NSApp.terminate(nil)
            return true
        } catch {
            log.error("could not restart: \(error.localizedDescription)")
            return false
        }
    }
}
