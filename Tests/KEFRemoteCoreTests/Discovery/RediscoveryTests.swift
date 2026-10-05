import Testing
import Foundation
@testable import KEFRemoteCore

struct RediscoveryTests {

    static let kefLocation = "http://192.168.1.80:8080/description.xml"

    func finder(log: MockKEFLog = MockKEFLog(), describing description: Data = Fixtures.description()) -> SpeakerFinder {
        let socket = MockDatagramSocket(replies: [
            Datagram(data: Fixtures.reply(location: Self.kefLocation), fromHost: "192.168.1.80"),
        ])
        return SpeakerFinder(
            makeSocket: { socket },
            fetcher: MockDescriptionFetcher([Self.kefLocation: description]),
            log: log
        )
    }

    @Test func aSpeakerThatMovedGetsItsNewIPSaved() async throws {
        let saved = AppConfig.SpeakerConfig(name: "LSX", mac: "a1:b2:c3:d4:e5:f6", lastKnownIp: "192.168.1.42")

        let updated = try await finder().rediscover(saved)

        #expect(updated == AppConfig.SpeakerConfig(name: "LSX", mac: "a1:b2:c3:d4:e5:f6", lastKnownIp: "192.168.1.80"))
    }

    @Test func withNoSpeakerSavedTheFirstKEFIsSavedWithItsMACAndName() async throws {
        let updated = try await finder().rediscover(nil)

        #expect(updated == AppConfig.SpeakerConfig(name: "LSX", mac: "A1B2C3D4E5F6", lastKnownIp: "192.168.1.80"))
    }

    @Test func aSavedIPWithNoMACGainsTheMAC() async throws {
        let saved = AppConfig.SpeakerConfig(lastKnownIp: "192.168.1.42")

        let updated = try await finder().rediscover(saved)

        #expect(updated?.mac == "A1B2C3D4E5F6")
        #expect(updated?.lastKnownIp == "192.168.1.80")
    }

    @Test func nothingFoundMeansNothingToSave() async throws {
        let saved = AppConfig.SpeakerConfig(mac: "00:11:22:33:44:55", lastKnownIp: "192.168.1.42")

        let updated = try await finder().rediscover(saved)

        #expect(updated == nil)
    }

    @Test func logsTheMove() async throws {
        let log = MockKEFLog()
        let saved = AppConfig.SpeakerConfig(mac: "A1B2C3D4E5F6", lastKnownIp: "192.168.1.42")

        _ = try await finder(log: log).rediscover(saved)

        #expect(log.messages(at: .info).contains("Discovery: speaker moved from 192.168.1.42 to 192.168.1.80"))
    }

    @Test func connectionErrorsCallForRediscovery() {
        #expect(KEFError.connectionFailed("timed out").isConnectionFailure)
        #expect(KEFError.notConnected.isConnectionFailure)
        #expect(KEFError.commandTimeout.isConnectionFailure)
        #expect(!KEFError.invalidResponse.isConnectionFailure)
    }
}
