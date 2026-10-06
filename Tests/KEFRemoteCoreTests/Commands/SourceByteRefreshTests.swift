import Foundation
import Testing
@testable import KEFRemoteCore

/// Opening the menu reads the speaker's input again, so Input ▸ and Turn
/// speaker on/off aren't stale after the speaker changed by itself
/// (hand test round 5: AirPlay switched it to Wi-Fi, the menu still said
/// Optical). At most one read per open, and never on top of a command.
/// Opening Settings reads it the same way, for what the speaker is set
/// to now (hand test round 6).
struct SourceByteRefreshTests {

    /// Settings shows standby, input and swap from the same byte, so its
    /// lines name the byte.
    @Test func settingsLogsTheSameDecisionsUnderItsOwnName() {
        let stale = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(12))
        #expect(stale.logLine(on: .settings) == "Settings opened: reading the speaker's source byte (last read 12 s ago)")
        let fresh = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(1))
        #expect(fresh.logLine(on: .settings) == "Settings opened: source byte read 1 s ago, not reading it again")
        #expect(SourceByteRefresh.skipBusy.logLine(on: .settings)
            == "Settings opened: not reading the source byte, a command is talking to the speaker")
        #expect(SourceByteRefresh.skipNotConnected.logLine(on: .settings)
            == "Settings opened: not reading the source byte, the speaker isn't connected")
    }

    @Test func aStaleByteIsReadAgain() {
        let read = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(12))
        #expect(read == .read(lastReadAgo: .seconds(12)))
        #expect(read.reads)
        #expect(read.logLine(on: .menu) == "menu opened: reading the speaker's input (last read 12 s ago)")
    }

    @Test func aByteNeverReadIsRead() {
        let read = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: nil)
        #expect(read == .read(lastReadAgo: nil))
        #expect(read.logLine(on: .menu) == "menu opened: reading the speaker's input (not read yet)")
    }

    @Test func aByteReadJustNowIsNotReadAgain() {
        let read = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(1))
        #expect(read == .skipReadRecently(.seconds(1)))
        #expect(!read.reads)
        #expect(read.logLine(on: .menu) == "menu opened: input read 1 s ago, not reading it again")
    }

    @Test func theFreshWindowEndsAtItsLimit() {
        let atLimit = SourceByteRefresh(isConnected: true, isExchangeInFlight: false, sourceByteAge: SourceByteRefresh.freshFor)
        #expect(atLimit.reads)
        let justUnder = SourceByteRefresh(
            isConnected: true, isExchangeInFlight: false, sourceByteAge: SourceByteRefresh.freshFor - .milliseconds(1)
        )
        #expect(!justUnder.reads)
    }

    /// The connection can't take two exchanges at once: the second reply
    /// would be read as the first's.
    @Test func itNeverReadsWhileACommandIsTalkingToTheSpeaker() {
        let read = SourceByteRefresh(isConnected: true, isExchangeInFlight: true, sourceByteAge: .seconds(30))
        #expect(read == .skipBusy)
        #expect(read.logLine(on: .menu) == "menu opened: not reading the input, a command is talking to the speaker")
    }

    /// A read would wait for the connection to time out, and the menu
    /// already shows it isn't connected.
    @Test func itDoesNotReadWhileNotConnected() {
        let read = SourceByteRefresh(isConnected: false, isExchangeInFlight: false, sourceByteAge: .seconds(30))
        #expect(read == .skipNotConnected)
        #expect(read.logLine(on: .menu) == "menu opened: not reading the input, the speaker isn't connected")
    }

    @Test func aFewSecondsCountAsFresh() {
        #expect(SourceByteRefresh.freshFor >= .seconds(2))
        #expect(SourceByteRefresh.freshFor <= .seconds(5))
    }
}

/// What the controller tells the menu: how old its source byte is, and
/// whether an exchange is in flight.
struct SpeakerControllerMenuOpenTests {
    let on = SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: .optical)

    private static func reply(_ source: SourceByte) -> Data {
        Data([0x52, 0x30, 0x81, source.encode(), 0x00])
    }

    @Test func beforeAnyReadTheByteHasNoAge() {
        let controller = SpeakerController(connection: MockSpeakerConnection(), clock: SimulatedClock())
        #expect(controller.sourceByteAge == nil)
    }

    @Test func theAgeCountsFromTheLastRead() async throws {
        let clock = SimulatedClock()
        let mock = MockSpeakerConnection()
        mock.responses = [Self.reply(on)]
        let controller = SpeakerController(connection: mock, clock: clock)

        _ = try await controller.getSourceByte()
        #expect(controller.sourceByteAge == .zero)

        await clock.sleep(for: .seconds(7))
        #expect(controller.sourceByteAge == .seconds(7))
    }

    /// A write the speaker acked is as good as a read: the app knows the byte.
    @Test func anAckedWriteResetsTheAge() async throws {
        let clock = SimulatedClock()
        let mock = MockSpeakerConnection()
        mock.responses = [Self.reply(on), Data([0x52, 0x11, 0xFF])]
        let controller = SpeakerController(connection: mock, clock: clock)

        await clock.sleep(for: .seconds(9))
        try await controller.setInput(.wifi)

        #expect(controller.sourceByteAge == .zero)
    }

    @Test func anExchangeIsInFlightUntilItsReplyComes() async throws {
        let connection = PeekingConnection(reply: Self.reply(on))
        let controller = SpeakerController(connection: connection, clock: SimulatedClock())
        connection.peek = { [weak controller] in connection.seenInFlight = controller?.isExchangeInFlight }

        #expect(!controller.isExchangeInFlight)
        _ = try await controller.getSourceByte()

        #expect(connection.seenInFlight == true)
        #expect(!controller.isExchangeInFlight)
    }

    @Test func aFailedExchangeIsNoLongerInFlight() async {
        let mock = MockSpeakerConnection()
        mock.errorToThrow = .connectionFailed("gone")
        let controller = SpeakerController(connection: mock, clock: SimulatedClock())

        await #expect(throws: KEFError.self) { _ = try await controller.getSourceByte() }

        #expect(!controller.isExchangeInFlight)
    }

    @Test func theSourceByteRefreshUsesTheControllersState() async throws {
        let clock = SimulatedClock()
        let mock = MockSpeakerConnection()
        mock.responses = [Self.reply(on)]
        let controller = SpeakerController(connection: mock, clock: clock)

        #expect(controller.sourceByteRefresh(isConnected: true) == .read(lastReadAgo: nil))
        _ = try await controller.getSourceByte()
        #expect(controller.sourceByteRefresh(isConnected: true) == .skipReadRecently(.zero))
        await clock.sleep(for: .seconds(4))
        #expect(controller.sourceByteRefresh(isConnected: true) == .read(lastReadAgo: .seconds(4)))
        #expect(controller.sourceByteRefresh(isConnected: false) == .skipNotConnected)
    }
}

/// Calls `peek` while a send is waiting for its reply.
private final class PeekingConnection: SpeakerConnection {
    let reply: Data
    var peek: () -> Void = {}
    var seenInFlight: Bool?

    init(reply: Data) { self.reply = reply }

    func send(_ data: Data, expectResponseBytes: Int) async throws -> Data {
        peek()
        return reply
    }
}
