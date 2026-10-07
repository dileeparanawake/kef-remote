import Foundation
import Testing
@testable import KEFRemoteCore

/// Paths in the log start with ~, so a log sent with feedback doesn't
/// carry the Mac's account name.
struct LogPathTests {

    private let home = "/Users/someone"

    @Test func aFileInTheHomeFolderStartsWithATilde() {
        let config = URL(fileURLWithPath: "/Users/someone/.kef-remote/config.json")
        #expect(LogPath.abbreviated(config, home: home) == "~/.kef-remote/config.json")
    }

    @Test func theHomeFolderItselfIsATilde() {
        #expect(LogPath.abbreviated(URL(fileURLWithPath: "/Users/someone"), home: home) == "~")
    }

    @Test func aHomeWrittenWithATrailingSlashStillMatches() {
        let config = URL(fileURLWithPath: "/Users/someone/.kef-remote/config.json")
        #expect(LogPath.abbreviated(config, home: "/Users/someone/") == "~/.kef-remote/config.json")
    }

    @Test func aPathOutsideTheHomeFolderIsLoggedAsItIs() {
        let temp = URL(fileURLWithPath: "/tmp/kef/config.json")
        #expect(LogPath.abbreviated(temp, home: home) == "/tmp/kef/config.json")
    }

    /// Another account whose name starts with the same letters isn't home.
    @Test func aFolderThatOnlyStartsLikeHomeIsNotHome() {
        let other = URL(fileURLWithPath: "/Users/someoneelse/.kef-remote/config.json")
        #expect(LogPath.abbreviated(other, home: home) == "/Users/someoneelse/.kef-remote/config.json")
    }

    @Test func byDefaultItUsesThisMacsHomeFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kef-remote/config.json")
        #expect(LogPath.abbreviated(url) == "~/.kef-remote/config.json")
    }
}
