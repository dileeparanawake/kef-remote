import Testing
@testable import KEFRemoteCore

struct SpeakerIPTests {

    @Test func aTypedIPWithSpacesAroundItIsAccepted() {
        #expect(SpeakerIP.parse(" 192.168.1.80 \n") == "192.168.1.80")
    }

    @Test(arguments: ["", "   ", "192.168.1", "192.168.1.256", "192.168.1.80.1", "lsx.local", "192.168.1.-1", "192.168.1.8a"])
    func textThatIsNotAnIPv4AddressIsRejected(text: String) {
        #expect(SpeakerIP.parse(text) == nil)
    }
}
