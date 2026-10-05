import Testing
import Foundation
@testable import KEFRemoteCore

struct KEFLogTests {

    @Test func mockRecordsEachLevelInOrder() {
        let log = MockKEFLog()
        log.debug("d")
        log.info("i")
        log.warning("w")
        log.error("e")

        #expect(log.entries == [
            .init(level: .debug, message: "d"),
            .init(level: .info, message: "i"),
            .init(level: .warning, message: "w"),
            .init(level: .error, message: "e"),
        ])
    }

    @Test func handlerLogPassesLevelAndMessageToTheClosure() {
        var received: [(KEFLogLevel, String)] = []
        let log = HandlerLog { level, message in received.append((level, message)) }

        log.warning("speaker moved")

        #expect(received.count == 1)
        #expect(received.first?.0 == .warning)
        #expect(received.first?.1 == "speaker moved")
    }

    @Test func hexStringFormatsBytesAsSpacedUppercasePairs() {
        #expect(Data([0x47, 0x25, 0x80]).hexString == "47 25 80")
        #expect(Data().hexString == "")
    }
}
