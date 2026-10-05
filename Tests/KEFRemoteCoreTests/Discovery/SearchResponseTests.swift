import Testing
import Foundation
@testable import KEFRemoteCore

struct SearchResponseTests {

    @Test func readsLocationAndSearchTargetFromAKEFReply() throws {
        let reply = Fixtures.reply(location: "http://192.168.1.80:8080/description.xml")

        let response = try #require(SearchResponse.parse(reply))

        #expect(response.location == URL(string: "http://192.168.1.80:8080/description.xml"))
        #expect(response.host == "192.168.1.80")
        #expect(response.searchTarget == "urn:schemas-upnp-org:device:MediaRenderer:1")
        #expect(response.isMediaRenderer)
    }

    @Test func headerNamesAreCaseInsensitive() throws {
        let reply = Data("HTTP/1.1 200 OK\r\nLocation: http://10.0.0.5/d.xml\r\nst: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n".utf8)

        let response = try #require(SearchResponse.parse(reply))

        #expect(response.host == "10.0.0.5")
        #expect(response.isMediaRenderer)
    }

    @Test func aHueReplyIsNotAMediaRenderer() throws {
        let reply = Fixtures.reply(
            location: "http://192.168.1.131:80/description.xml",
            st: "upnp:rootdevice",
            server: "Hue/1.0 UPnP/1.0 IpBridge/1.78.0"
        )

        let response = try #require(SearchResponse.parse(reply))

        #expect(!response.isMediaRenderer)
    }

    @Test func aReplyWithoutLocationIsNotParsed() {
        let reply = Data("HTTP/1.1 200 OK\r\nST: upnp:rootdevice\r\n\r\n".utf8)
        #expect(SearchResponse.parse(reply) == nil)
    }

    @Test func anotherSearchRequestIsNotAReply() {
        #expect(SearchResponse.parse(SSDPSearch.mediaRendererRequest) == nil)
    }

    @Test func searchRequestAsksForMediaRenderers() throws {
        let text = try #require(String(data: SSDPSearch.mediaRendererRequest, encoding: .utf8))

        #expect(text.hasPrefix("M-SEARCH * HTTP/1.1\r\n"))
        #expect(text.contains("HOST: 239.255.255.250:1900\r\n"))
        #expect(text.contains("MAN: \"ssdp:discover\"\r\n"))
        #expect(text.contains("MX: 2\r\n"))
        #expect(text.contains("ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n"))
        #expect(text.hasSuffix("\r\n\r\n"))
    }
}
