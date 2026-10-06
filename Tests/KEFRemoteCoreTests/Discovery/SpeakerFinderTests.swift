import Testing
import Foundation
@testable import KEFRemoteCore

struct SpeakerFinderTests {

    static let hueLocation = "http://192.168.1.131:80/description.xml"
    static let kefLocation = "http://192.168.1.80:8080/description.xml"

    static let hueReply = Datagram(
        data: Fixtures.reply(location: hueLocation, st: "upnp:rootdevice", server: "Hue/1.0 UPnP/1.0 IpBridge/1.78.0"),
        fromHost: "192.168.1.131"
    )
    static let kefReply = Datagram(data: Fixtures.reply(location: kefLocation), fromHost: "192.168.1.80")

    func makeFinder(
        socket: MockDatagramSocket,
        fetcher: MockDescriptionFetcher,
        log: MockKEFLog = MockKEFLog()
    ) -> SpeakerFinder {
        SpeakerFinder(makeSocket: { socket }, fetcher: fetcher, log: log)
    }

    @Test func skipsTheHueAndFindsTheKEF() async throws {
        let socket = MockDatagramSocket(replies: [Self.hueReply, Self.kefReply])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description()])

        let found = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: nil)

        #expect(found == FoundSpeaker(ip: "192.168.1.80", mac: "A1B2C3D4E5F6", name: "LSX", model: "SP3994"))
        #expect(fetcher.fetched == [URL(string: Self.kefLocation)!])
    }

    @Test func withTwoKEFsPicksTheOneWithTheSavedMAC() async throws {
        let otherLocation = "http://192.168.1.90:8080/description.xml"
        let socket = MockDatagramSocket(replies: [
            Datagram(data: Fixtures.reply(location: otherLocation), fromHost: "192.168.1.90"),
            Self.kefReply,
        ])
        let fetcher = MockDescriptionFetcher([
            otherLocation: Fixtures.description(friendlyName: "Kitchen", serialNumber: "001122334455"),
            Self.kefLocation: Fixtures.description(),
        ])

        let found = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: "a1:b2:c3:d4:e5:f6")

        #expect(found?.ip == "192.168.1.80")
        #expect(found?.name == "LSX")
    }

    @Test func aRendererFromAnotherMakerIsNotFound() async throws {
        let socket = MockDatagramSocket(replies: [Self.kefReply])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description(manufacturer: "Sonos, Inc.")])

        let found = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: nil)

        #expect(found == nil)
    }

    @Test func aKEFWithAnotherMACIsNotFound() async throws {
        let socket = MockDatagramSocket(replies: [Self.kefReply])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description()])

        let found = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: "00:11:22:33:44:55")

        #expect(found == nil)
    }

    @Test func sendsTheMediaRendererSearchTwiceWhenNothingAnswers() async throws {
        let socket = MockDatagramSocket()

        let found = try await makeFinder(socket: socket, fetcher: MockDescriptionFetcher()).find(savedMAC: nil)

        #expect(found == nil)
        let search = MockDatagramSocket.Sent(data: SSDPSearch.mediaRendererRequest, host: "239.255.255.250", port: 1900)
        #expect(socket.sent == [search, search])
        #expect(socket.isClosed)
    }

    @Test func aSendFailureThrowsAndClosesTheSocket() async throws {
        struct NoRoute: Error {}
        let socket = MockDatagramSocket()
        socket.sendError = NoRoute()

        await #expect(throws: NoRoute.self) {
            try await makeFinder(socket: socket, fetcher: MockDescriptionFetcher()).find(savedMAC: nil)
        }
        #expect(socket.isClosed)
    }

    @Test func aDescriptionThatFailsToLoadIsSkipped() async throws {
        let brokenLocation = "http://192.168.1.50:8080/description.xml"
        let socket = MockDatagramSocket(replies: [
            Datagram(data: Fixtures.reply(location: brokenLocation), fromHost: "192.168.1.50"),
            Self.kefReply,
        ])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description()])

        let found = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: nil)

        #expect(found?.ip == "192.168.1.80")
    }

    @Test func aRepeatedReplyIsFetchedOnce() async throws {
        let socket = MockDatagramSocket(replies: [Self.kefReply, Self.kefReply])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description(manufacturer: "Other")])

        _ = try await makeFinder(socket: socket, fetcher: fetcher).find(savedMAC: nil)

        #expect(fetcher.fetched.count == 1)
    }

    @Test func logsWhatItSentHeardKeptAndDropped() async throws {
        let socket = MockDatagramSocket(replies: [Self.hueReply, Self.kefReply])
        let fetcher = MockDescriptionFetcher([Self.kefLocation: Fixtures.description()])
        let log = MockKEFLog()

        _ = try await makeFinder(socket: socket, fetcher: fetcher, log: log).find(savedMAC: nil)

        let info = log.messages(at: .info)
        #expect(info.contains { $0.hasPrefix("Discovery: sent M-SEARCH 1 of 2") })
        #expect(info.contains { $0.hasPrefix("Discovery: heard 192.168.1.131") })
        #expect(info.contains { $0.hasPrefix("Discovery: dropped 192.168.1.131: ST is not MediaRenderer") })
        #expect(info.contains { $0.hasPrefix("Discovery: kept 192.168.1.80: KEF LSX") })
        #expect(log.messages(at: .debug).contains { $0.contains("KnOS/3.2") })
    }

    @Test func logsAWarningWhenNothingIsFound() async throws {
        let log = MockKEFLog()

        _ = try await makeFinder(socket: MockDatagramSocket(), fetcher: MockDescriptionFetcher(), log: log).find(savedMAC: nil)

        #expect(log.messages(at: .warning) == ["Discovery: no matching KEF found (2 searches, 0 replies heard)"])
    }
}
