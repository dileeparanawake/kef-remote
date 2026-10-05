import Foundation
import Testing
@testable import KEFRemoteCore

struct DiscoveryOutcomeTests {

    @Test func aFoundSpeakerIsNamedWithItsIP() {
        let found = AppConfig.SpeakerConfig(name: "LSX", mac: "a1b2c3d4e5f6", lastKnownIp: "192.168.1.80")

        #expect(DiscoveryOutcome.found(found).message == "Found LSX at 192.168.1.80")
    }

    @Test func whenNoKEFAnswersSettingsSaysSo() {
        #expect(DiscoveryOutcome.notFound.message == "No KEF speaker answered")
    }

    @Test func aFailedSearchShowsWhy() {
        #expect(DiscoveryOutcome.failed("socket closed").message == "Discovery failed: socket closed")
    }

    @Test func aSecondPressWhileSearchingIsNotARun() {
        #expect(DiscoveryOutcome.alreadyRunning.message == "Already looking")
    }

    @Test func noRouteToHostPointsAtTheLocalNetworkPermission() {
        let outcome = DiscoveryOutcome.failure(SocketError("sendto", code: EHOSTUNREACH))

        #expect(outcome.message.hasSuffix("Allow KEF Remote in System Settings > Privacy & Security > Local Network."))
    }

    @Test func otherSocketErrorsShowJustTheError() {
        let outcome = DiscoveryOutcome.failure(SocketError("bind", code: EADDRINUSE))

        #expect(outcome == .failed("bind failed: Address already in use (errno 48)"))
    }
}
