import Testing
@testable import KEFRemoteCore

@Suite("LogLevel")
struct LogLevelTests {

    @Test("ordering: debug < info < warning < error")
    func ordering() {
        #expect(LogLevel.debug < .info)
        #expect(LogLevel.info < .warning)
        #expect(LogLevel.warning < .error)
        #expect(LogLevel.debug < .error)
    }

    @Test("labels match expected strings")
    func labels() {
        #expect(LogLevel.debug.label == "DEBUG")
        #expect(LogLevel.info.label == "INFO")
        #expect(LogLevel.warning.label == "WARN")
        #expect(LogLevel.error.label == "ERROR")
    }
}
