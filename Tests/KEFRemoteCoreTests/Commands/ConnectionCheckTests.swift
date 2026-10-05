import Testing
import Foundation
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
