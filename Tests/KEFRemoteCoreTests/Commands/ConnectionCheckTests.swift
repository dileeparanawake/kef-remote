import Testing
import Foundation
import Network
@testable import KEFRemoteCore

/// The check the app runs whenever it sets up a speaker connection,
/// and what it says to do when the speaker doesn't answer.
struct ConnectionCheckTests {

    /// Live test, 5 Oct: the saved IP was stale, the launch check timed
    /// out, and nothing looked for the speaker until the first key press
    /// failed. A stale saved IP must start discovery straight away.
    @Test func aSavedIPThatDoesNotAnswerStartsDiscovery() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.savedIP)

        #expect(outcome == .rediscover)
    }

    /// Discovery ends by checking the IP it settled on. If that fails too,
    /// searching again would loop (a speaker off at the wall never answers).
    @Test func aCheckAfterDiscoveryNeverStartsDiscoveryAgain() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.afterDiscovery)

        #expect(outcome == .notConnected)
    }

    /// The user chose this IP; discovery must not overrule it.
    @Test func anIPTypedInSettingsIsNotOverruledByDiscovery() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.typedInSettings)

        #expect(outcome == .notConnected)
    }

    /// With Local Network blocked, discovery can't run either: searching
    /// would only fail the same way.
    @Test func aBlockedLocalNetworkDoesNotStartDiscovery() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .localNetworkBlocked("Network is down")
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.savedIP)

        #expect(outcome == .notConnected)
    }

    /// An empty read means something answered at that IP, so it hasn't moved.
    @Test func anEmptyReadDoesNotStartDiscovery() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .invalidResponse
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.savedIP)

        #expect(outcome == .notConnected)
    }

    @Test func aFailedCheckLogsWhyAndWhatHappensNext() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let log = MockKEFLog()
        let controller = SpeakerController(connection: mock, log: log.handler)

        _ = await controller.checkConnection(.savedIP)

        #expect(log.messages(at: .warning) == [
            "Speaker did not answer the check (connectionFailed(\"timed out\")): the saved IP may be stale, looking for the speaker",
        ])
    }
}

/// Live test, 5 Oct: Discover in settings dropped the live connection and
/// reconnected at once; the speaker refused (it takes one connection at a
/// time), so the menu said Not connected until the next key press.
struct RefusedConnectionTests {

    static let sourceReply = Data([0x52, 0x30, 0x81, 0x82, 0x00])

    /// Retries without waiting, so the tests run fast.
    static let noWait = RefusalRetry(attempts: 2, pause: {})

    @Test func aRefusedConnectionIsTriedAgainAndThenAnswers() async {
        let mock = MockSpeakerConnection()
        mock.failures = [.connectionRefused]
        mock.responses = [Self.sourceReply]
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.afterDiscovery, refusalRetry: Self.noWait)

        #expect(outcome == .answered)
        #expect(mock.sentCommands == [KEFCommand.getSource(), KEFCommand.getSource()])
    }

    @Test func aSpeakerThatKeepsRefusingIsGivenUpOnAfterTheRetries() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionRefused
        let controller = SpeakerController(connection: mock)

        let outcome = await controller.checkConnection(.afterDiscovery, refusalRetry: Self.noWait)

        #expect(outcome == .notConnected)
        #expect(mock.sentCommands.count == 3)
    }

    @Test func otherFailuresAreNotRetried() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("timed out")
        let controller = SpeakerController(connection: mock)

        _ = await controller.checkConnection(.afterDiscovery, refusalRetry: Self.noWait)

        #expect(mock.sentCommands.count == 1)
    }

    @Test func eachRetryIsLogged() async {
        let mock = MockSpeakerConnection()
        mock.failures = [.connectionRefused]
        mock.responses = [Self.sourceReply]
        let log = MockKEFLog()
        let controller = SpeakerController(connection: mock, log: log.handler)

        _ = await controller.checkConnection(.afterDiscovery, refusalRetry: Self.noWait)

        #expect(log.messages(at: .info).contains("Speaker refused the connection; trying again (1 of 2)"))
    }

    @Test func aRefusalStillMeansTheSpeakerCouldNotBeReached() {
        #expect(KEFError.connectionRefused.isConnectionFailure)
    }

    @Test func aRefusedTCPConnectionBecomesConnectionRefused() {
        #expect(KEFError(NWError.posix(.ECONNREFUSED)) == .connectionRefused)
    }

    @Test func otherTCPErrorsStayConnectionFailed() {
        let error = NWError.posix(.ETIMEDOUT)
        #expect(KEFError(error) == .connectionFailed(error.localizedDescription))
    }
}
