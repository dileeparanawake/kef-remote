import Testing
@testable import KEFRemoteCore

struct DiscoveryModeTests {

    @Test func autoLooksForTheSpeakerByItself() {
        #expect(DiscoveryMode.auto.searchesBySelf)
    }

    @Test func manualNeverLooksByItself() {
        #expect(!DiscoveryMode.manual.searchesBySelf)
    }

    /// The raw values are what config.json holds.
    @Test func savedAsAutoOrManual() {
        #expect(DiscoveryMode.auto.rawValue == "auto")
        #expect(DiscoveryMode.manual.rawValue == "manual")
    }
}
