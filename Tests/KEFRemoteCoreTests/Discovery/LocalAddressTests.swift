import Testing
@testable import KEFRemoteCore

/// Discovery fetches description.xml only from an address on this
/// network, so the app never reaches the internet.
struct LocalAddressTests {

    @Test(arguments: [
        "10.0.0.1", "10.255.255.255",           // 10/8
        "172.16.0.1", "172.31.255.254",         // 172.16/12
        "192.168.1.80", "192.168.0.0",          // 192.168/16
        "169.254.10.20",                        // link-local
        "127.0.0.1", "127.1.2.3",               // loopback
    ])
    func aPrivateLinkLocalOrLoopbackAddressIsLocal(_ host: String) {
        #expect(LocalAddress.isLocal(host))
    }

    @Test(arguments: [
        "8.8.8.8", "93.184.216.34",             // the internet
        "172.15.255.255", "172.32.0.1",         // either side of 172.16/12
        "192.169.1.1", "169.253.1.1", "11.0.0.1",
    ])
    func aPublicAddressIsNotLocal(_ host: String) {
        #expect(!LocalAddress.isLocal(host))
    }

    /// A name would need DNS, which could point anywhere.
    @Test(arguments: ["example.com", "kef.local", "localhost"])
    func aNameIsNotLocal(_ host: String) {
        #expect(!LocalAddress.isLocal(host))
    }

    @Test(arguments: ["192.168.1", "192.168.1.1.1", "192.168.1.256", "192.168.-1.1", "192.168.1.", "", "::1", "fe80::1", "192.168.01.80x"])
    func anythingButFourNumbersUpTo255IsNotLocal(_ host: String) {
        #expect(!LocalAddress.isLocal(host))
    }
}
