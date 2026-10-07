import Foundation

/// A file path as the log writes it: under the home folder it starts
/// with `~`, so the Mac's account name (often the person's name) stays
/// out of a log sent with feedback.
///
/// ```
/// /Users/someone/.kef-remote/config.json  ->  ~/.kef-remote/config.json
/// /tmp/kef/config.json                    ->  /tmp/kef/config.json
/// ```
public enum LogPath {
    /// - Parameter home: The home folder; this Mac's unless a test passes one.
    public static func abbreviated(_ url: URL, home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String {
        let path = url.path
        let homeFolder = home.hasSuffix("/") ? String(home.dropLast()) : home
        if path == homeFolder { return "~" }
        // With the slash, so /Users/someoneelse isn't read as /Users/someone.
        guard path.hasPrefix(homeFolder + "/") else { return path }
        return "~" + path.dropFirst(homeFolder.count)
    }
}
