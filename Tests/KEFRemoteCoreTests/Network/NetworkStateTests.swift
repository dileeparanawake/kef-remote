import Testing
@testable import KEFRemoteCore

struct NetworkStateTests {

    @Test func withNoHomeNetworkSetTheAppWorksEverywhere() {
        #expect(NetworkState.on(currentSSID: "Cafe", homeSSID: nil) == .active)
        #expect(NetworkState.on(currentSSID: nil, homeSSID: nil) == .active)
    }

    @Test func onTheHomeNetworkTheAppIsActive() {
        #expect(NetworkState.on(currentSSID: "Home", homeSSID: "Home") == .active)
    }

    @Test func onAnotherNetworkTheAppIsDormant() {
        #expect(NetworkState.on(currentSSID: "Cafe", homeSSID: "Home") == .dormant)
    }

    @Test func offWiFiTheAppIsDormant() {
        #expect(NetworkState.on(currentSSID: nil, homeSSID: "Home") == .dormant)
    }

    @Test func theNameMustMatchCaseToo() {
        #expect(NetworkState.on(currentSSID: "home", homeSSID: "Home") == .dormant)
    }
}
