import Testing
@testable import KEFRemoteCore

struct ConnectionStatusTests {

    @Test func offTheHomeNetworkTheStatusIsDormantEvenWithASpeakerSet() {
        #expect(ConnectionStatus.idle(isActive: false, speakerIP: "192.168.1.80") == .dormant)
    }

    @Test func onTheHomeNetworkWithNoIPTheStatusIsNoSpeaker() {
        #expect(ConnectionStatus.idle(isActive: true, speakerIP: nil) == .noSpeaker)
        #expect(ConnectionStatus.idle(isActive: true, speakerIP: "") == .noSpeaker)
    }

    @Test func onTheHomeNetworkWithAnIPTheStatusIsConnecting() {
        #expect(ConnectionStatus.idle(isActive: true, speakerIP: "192.168.1.80") == .connecting)
    }

    @Test func aSpeakerThatAnsweredIsConnected() {
        #expect(ConnectionStatus(.answered) == .connected)
    }

    @Test func aSpeakerThatCouldNotBeReachedIsNotConnected() {
        #expect(ConnectionStatus(.unreachable("timed out")) == .notConnected)
    }
}
