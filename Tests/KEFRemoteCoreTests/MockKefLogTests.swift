import Testing
@testable import KEFRemoteCore

@Suite("MockKefLog")
struct MockKefLogTests {

    @Test("captures messages at correct level")
    func capturesAtCorrectLevel() {
        let log = MockKefLog(category: "Test")

        log.debug("d")
        log.info("i")
        log.warning("w")
        log.error("e")

        #expect(log.entries[0] == MockKefLog.Entry(level: .debug, message: "d"))
        #expect(log.entries[1] == MockKefLog.Entry(level: .info, message: "i"))
        #expect(log.entries[2] == MockKefLog.Entry(level: .warning, message: "w"))
        #expect(log.entries[3] == MockKefLog.Entry(level: .error, message: "e"))
    }

    @Test("reports correct category")
    func reportsCategory() {
        let log = MockKefLog(category: "SpeakerClient")
        #expect(log.category == "SpeakerClient")
    }

    @Test("captures multiple messages in order")
    func capturesInOrder() {
        let log = MockKefLog(category: "Test")

        log.info("first")
        log.info("second")
        log.info("third")

        #expect(log.entries.count == 3)
        #expect(log.entries[0].message == "first")
        #expect(log.entries[1].message == "second")
        #expect(log.entries[2].message == "third")
    }
}
