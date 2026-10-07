import Testing
import Foundation
@testable import KEFRemoteCore

struct LogFileWriterTests {

    // MARK: - Helpers

    /// A fresh folder per test, removed when the test ends.
    final class TempFolder {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-log-test-\(UUID().uuidString)")

        deinit { try? FileManager.default.removeItem(at: url) }

        func file(_ name: String = "kef-remote.log") -> URL {
            url.appendingPathComponent(name)
        }
    }

    /// Records every line the writer echoes (stderr in the app).
    final class EchoRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [String] = []

        var lines: [String] {
            lock.lock(); defer { lock.unlock() }
            return recorded
        }

        func record(_ line: String) {
            lock.lock(); defer { lock.unlock() }
            recorded.append(line)
        }
    }

    private func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Writing

    @Test func lineIsInTheFileAsSoonAsWriteReturns() throws {
        let folder = TempFolder()
        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in })

        writer.write(.info, category: "AppDelegate", message: "KEF Remote launched")

        // No wait: a kill straight after write must not lose the line.
        #expect(try contents(of: folder.file()).hasSuffix("[INFO] [AppDelegate] KEF Remote launched\n"))
    }

    @Test func lineStartsWithATimestamp() throws {
        let folder = TempFolder()
        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in })

        writer.write(.info, category: "net", message: "hello")

        let line = try contents(of: folder.file())
        #expect(line.wholeMatch(of: #/\[\d{2}:\d{2}:\d{2}\.\d{3}\] \[INFO\] \[net\] hello\n/#) != nil)
    }

    @Test func eachLevelHasTheLabelTheMakeFiltersLookFor() throws {
        let folder = TempFolder()
        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in })

        writer.write(.debug, category: "c", message: "d")
        writer.write(.info, category: "c", message: "i")
        writer.write(.warning, category: "c", message: "w")
        writer.write(.error, category: "c", message: "e")

        let lines = try contents(of: folder.file()).split(separator: "\n")
        #expect(lines.count == 4)
        #expect(lines[0].contains("[DEBUG] [c] d"))
        #expect(lines[1].contains("[INFO] [c] i"))
        #expect(lines[2].contains("[WARN] [c] w"))
        #expect(lines[3].contains("[ERROR] [c] e"))
    }

    @Test func echoGetsTheSameLineAsTheFile() throws {
        let folder = TempFolder()
        let echo = EchoRecorder()
        let writer = LogFileWriter(fileURL: folder.file(), echo: { echo.record($0) })

        writer.write(.warning, category: "speaker", message: "reply dropped")

        #expect(echo.lines == [try contents(of: folder.file())])
    }

    @Test func linesFromManyThreadsStayWhole() throws {
        let folder = TempFolder()
        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in })

        DispatchQueue.concurrentPerform(iterations: 200) { index in
            writer.write(.debug, category: "load", message: "line \(index)")
        }

        let lines = try contents(of: folder.file()).split(separator: "\n")
        #expect(lines.count == 200)
        #expect(lines.allSatisfy { $0.contains("[DEBUG] [load] line ") })
    }

    // MARK: - Opening the file

    @Test func makesTheLogFolderWhenMissing() throws {
        let folder = TempFolder()
        let nested = folder.url.appendingPathComponent("logs").appendingPathComponent("kef-remote.log")

        let writer = LogFileWriter(fileURL: nested, echo: { _ in })
        writer.write(.info, category: "c", message: "m")

        #expect(writer.isWritingToFile)
        #expect(try contents(of: nested).contains("[INFO] [c] m"))
    }

    @Test func startsAFreshFileEachLaunch() throws {
        let folder = TempFolder()
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try "last session\n".write(to: folder.file(), atomically: true, encoding: .utf8)

        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in })
        writer.write(.info, category: "c", message: "this session")

        let text = try contents(of: folder.file())
        #expect(!text.contains("last session"))
        #expect(text.contains("this session"))
    }

    @Test func appendingKeepsTheLinesAlreadyThere() throws {
        let folder = TempFolder()
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try "app session\n".write(to: folder.file(), atomically: true, encoding: .utf8)

        let writer = LogFileWriter(fileURL: folder.file(), echo: { _ in }, appending: true)
        writer.write(.info, category: "check", message: "check run")

        let lines = try contents(of: folder.file()).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "app session")
        #expect(lines[1].hasSuffix("[INFO] [check] check run"))
    }

    @Test func appendingMakesTheFileWhenMissing() throws {
        let folder = TempFolder()
        let nested = folder.url.appendingPathComponent("logs").appendingPathComponent("kef-remote.log")

        let writer = LogFileWriter(fileURL: nested, echo: { _ in }, appending: true)
        writer.write(.info, category: "check", message: "first line")

        #expect(writer.isWritingToFile)
        #expect(try contents(of: nested).hasSuffix("[INFO] [check] first line\n"))
    }

    @Test func defaultFileIsTheOneTheMakeTargetsRead() {
        #expect(LogFileWriter.defaultFileURL.path.hasSuffix("/.kef-remote/logs/kef-remote.log"))
    }

    @Test func saysSoWhenTheFileCannotBeMade() throws {
        let folder = TempFolder()
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        // A plain file where the log folder should be: the folder can't be made.
        let blocker = folder.file("not-a-folder")
        try "".write(to: blocker, atomically: true, encoding: .utf8)
        let echo = EchoRecorder()

        let writer = LogFileWriter(
            fileURL: blocker.appendingPathComponent("kef-remote.log"),
            echo: { echo.record($0) }
        )
        writer.write(.error, category: "c", message: "still shown")

        #expect(!writer.isWritingToFile)
        #expect(echo.lines.count == 2)
        #expect(echo.lines.first?.contains("[WARN] [LogFileWriter] Log file unavailable") == true)
        #expect(echo.lines.last?.contains("[ERROR] [c] still shown") == true)
    }
}
