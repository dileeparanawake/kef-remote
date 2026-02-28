import Testing
import Foundation
@testable import KEFRemoteCore

struct SSDPResponseParsingTests {

    @Test func parsesLocationFromResponse() {
        let response = "HTTP/1.1 200 OK\r\nLOCATION: http://192.168.1.42:8080/description.xml\r\nST: upnp:rootdevice\r\nUSN: uuid:test-uuid::upnp:rootdevice\r\n\r\n"
        let result = SSDPDiscovery.parseResponse(response)
        #expect(result?.location == "http://192.168.1.42:8080/description.xml")
        #expect(result?.ip == "192.168.1.42")
    }

    @Test func returnsNilForResponseWithoutLocation() {
        let response = "HTTP/1.1 200 OK\r\nST: upnp:rootdevice\r\n\r\n"
        #expect(SSDPDiscovery.parseResponse(response) == nil)
    }

    @Test func extractsIPFromLocationURL() {
        let response = "HTTP/1.1 200 OK\r\nLOCATION: http://10.0.0.5:8080/desc.xml\r\n\r\n"
        let result = SSDPDiscovery.parseResponse(response)
        #expect(result?.ip == "10.0.0.5")
    }
}
