import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerDescriptionTests {

    @Test func readsTheFieldsDiscoveryNeeds() throws {
        let description = try #require(SpeakerDescription.parse(Fixtures.description()))

        #expect(description.manufacturer == "KEF")
        #expect(description.friendlyName == "LSX")
        #expect(description.modelName == "SP3994")
        #expect(description.serialNumber == "A1B2C3D4E5F6")
        #expect(description.isKEF)
    }

    @Test func anotherMakerIsNotKEF() throws {
        let description = try #require(SpeakerDescription.parse(Fixtures.description(manufacturer: "Sonos, Inc.")))
        #expect(!description.isKEF)
    }

    @Test func notXMLIsNotParsed() {
        #expect(SpeakerDescription.parse(Data("<html>nope".utf8)) == nil)
    }

    @Test func serialMatchesAMACWrittenWithColonsInLowerCase() throws {
        let description = try #require(SpeakerDescription.parse(Fixtures.description()))
        #expect(description.matches(mac: "a1:b2:c3:d4:e5:f6"))
        #expect(description.matches(mac: "A1-B2-C3-D4-E5-F6"))
        #expect(!description.matches(mac: "00:11:22:33:44:55"))
    }

    @Test func normalisedMACDropsSeparatorsAndUpperCases() {
        #expect(MACAddress.normalised(" a1:b2-c3d4.e5f6 ") == "A1B2C3D4E5F6")
    }
}
