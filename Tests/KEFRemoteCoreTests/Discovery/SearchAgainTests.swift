import Foundation
import Testing
@testable import KEFRemoteCore

/// Hand test, 6 Oct: the search made the moment Local Network was allowed
/// heard only the Hue bridge, and the menu bar said no speaker. Find
/// speaker found it 50 s later in under a second. A search the app makes
/// by itself now searches again a couple of times before giving up.
struct SearchAgainTests {

    static let kefLocation = "http://192.168.1.80:8080/description.xml"

    /// Hands out one socket per search: the speaker answers only from
    /// search `answersOn` (1-based), or never when nil.
    final class Sockets: @unchecked Sendable {
        private let lock = NSLock()
        private let answersOn: Int?
        private var made = 0

        init(answersOn: Int?) { self.answersOn = answersOn }

        var searches: Int { lock.withLock { made } }

        func next() -> DatagramSocket {
            let number = lock.withLock { made += 1; return made }
            guard number == answersOn else { return MockDatagramSocket() }
            return MockDatagramSocket(replies: [
                Datagram(data: Fixtures.reply(location: SearchAgainTests.kefLocation), fromHost: "192.168.1.80"),
            ])
        }
    }

    /// Records each pause instead of sleeping.
    final class Pauses: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Duration] = []
        var all: [Duration] { lock.withLock { recorded } }
        func pause(_ duration: Duration) { lock.withLock { recorded.append(duration) } }
    }

    func finder(_ sockets: Sockets, log: MockKEFLog = MockKEFLog()) -> SpeakerFinder {
        SpeakerFinder(
            makeSocket: { sockets.next() },
            fetcher: MockDescriptionFetcher([Self.kefLocation: Fixtures.description()]),
            log: log
        )
    }

    // MARK: - The rule

    @Test func itSearchesTwiceMoreThreeSecondsApart() {
        #expect(SearchAgain.times == 2)
        #expect(SearchAgain.pause == .seconds(3))
    }

    /// He's watching a click, and can click again: one search, a quick answer.
    @Test(arguments: [DiscoveryTrigger.findSpeakerInMenu, .findSpeakerInSetup, .discoverInSettings])
    func aClickSearchesOnce(trigger: DiscoveryTrigger) {
        #expect(SearchAgain.times(after: trigger) == 0)
    }

    @Test(arguments: [DiscoveryTrigger.localNetworkAllowed, .noIPSaved, .speakerUnreachable, .switchedToAuto])
    func aSearchTheAppMadeByItselfSearchesAgain(trigger: DiscoveryTrigger) {
        #expect(SearchAgain.times(after: trigger) == 2)
    }

    /// The words stay the ones the log used before, so old logs still match.
    @Test func eachTriggerLogsAsBefore() {
        #expect(DiscoveryTrigger.findSpeakerInMenu.description == "Find speaker in menu")
        #expect(DiscoveryTrigger.findSpeakerInSetup.description == "Find speaker in setup")
        #expect(DiscoveryTrigger.discoverInSettings.description == "Discover in settings")
        #expect(DiscoveryTrigger.localNetworkAllowed.description == "Local Network allowed")
        #expect(DiscoveryTrigger.noIPSaved.description == "no IP saved")
        #expect(DiscoveryTrigger.speakerUnreachable.description == "speaker unreachable")
        #expect(DiscoveryTrigger.switchedToAuto.description == "switched to Auto discovery")
    }

    // MARK: - Searching again

    @Test func aMissAfterLocalNetworkIsAllowedSearchesAgainAndFindsTheSpeaker() async throws {
        let sockets = Sockets(answersOn: 2)
        let pauses = Pauses()

        let updated = try await finder(sockets).rediscover(nil, trigger: .localNetworkAllowed, pause: pauses.pause)

        #expect(updated?.lastKnownIp == "192.168.1.80")
        #expect(sockets.searches == 2)
        #expect(pauses.all == [.seconds(3)])
    }

    @Test func itGivesUpAfterTwoMoreSearches() async throws {
        let sockets = Sockets(answersOn: nil)
        let pauses = Pauses()

        let updated = try await finder(sockets).rediscover(nil, trigger: .localNetworkAllowed, pause: pauses.pause)

        #expect(updated == nil)
        #expect(sockets.searches == 3)
        #expect(pauses.all == [.seconds(3), .seconds(3)])
    }

    @Test func aFirstSearchThatFindsItDoesNotSearchAgain() async throws {
        let sockets = Sockets(answersOn: 1)
        let pauses = Pauses()

        _ = try await finder(sockets).rediscover(nil, trigger: .speakerUnreachable, pause: pauses.pause)

        #expect(sockets.searches == 1)
        #expect(pauses.all.isEmpty)
    }

    @Test func aClickThatMissesSearchesOnce() async throws {
        let sockets = Sockets(answersOn: 2)
        let pauses = Pauses()

        let updated = try await finder(sockets).rediscover(nil, trigger: .findSpeakerInMenu, pause: pauses.pause)

        #expect(updated == nil)
        #expect(sockets.searches == 1)
        #expect(pauses.all.isEmpty)
    }

    @Test func eachRetryLogsOneLineWithWhy() async throws {
        let log = MockKEFLog()

        _ = try await finder(Sockets(answersOn: nil), log: log).rediscover(nil, trigger: .localNetworkAllowed, pause: { _ in })

        let retries = log.messages(at: .info).filter { $0.contains("searching again") }
        #expect(retries == [
            "Discovery: no KEF found (Local Network allowed); searching again in 3.0 seconds (1 of 2)",
            "Discovery: no KEF found (Local Network allowed); searching again in 3.0 seconds (2 of 2)",
        ])
    }
}
