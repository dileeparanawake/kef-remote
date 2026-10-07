import Foundation
import Testing
@testable import KEFRemoteCore

/// Opening the menu reads the speaker's input again, so Input ▸ and Turn
/// speaker on/off aren't stale after the speaker changed by itself
/// (hand test round 5: AirPlay switched it to Wi-Fi, the menu still said
/// Optical). At most one read per open, and never on top of a command.
struct MenuOpenReadTests {

    @Test func aStaleByteIsReadAgain() {
        let read = MenuOpenRead(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(12))
        #expect(read == .read(lastReadAgo: .seconds(12)))
        #expect(read.reads)
        #expect(read.logLine == "menu opened: reading the speaker's input (last read 12 s ago)")
    }

    @Test func aByteNeverReadIsRead() {
        let read = MenuOpenRead(isConnected: true, isExchangeInFlight: false, sourceByteAge: nil)
        #expect(read == .read(lastReadAgo: nil))
        #expect(read.logLine == "menu opened: reading the speaker's input (not read yet)")
    }

    @Test func aByteReadJustNowIsNotReadAgain() {
        let read = MenuOpenRead(isConnected: true, isExchangeInFlight: false, sourceByteAge: .seconds(1))
        #expect(read == .skipReadRecently(.seconds(1)))
        #expect(!read.reads)
        #expect(read.logLine == "menu opened: input read 1 s ago, not reading it again")
    }

    @Test func theFreshWindowEndsAtItsLimit() {
        let atLimit = MenuOpenRead(isConnected: true, isExchangeInFlight: false, sourceByteAge: MenuOpenRead.freshFor)
        #expect(atLimit.reads)
        let justUnder = MenuOpenRead(
            isConnected: true, isExchangeInFlight: false, sourceByteAge: MenuOpenRead.freshFor - .milliseconds(1)
        )
        #expect(!justUnder.reads)
    }

    /// The connection can't take two exchanges at once: the second reply
    /// would be read as the first's.
    @Test func itNeverReadsWhileACommandIsTalkingToTheSpeaker() {
        let read = MenuOpenRead(isConnected: true, isExchangeInFlight: true, sourceByteAge: .seconds(30))
        #expect(read == .skipBusy)
        #expect(read.logLine == "menu opened: not reading the input, a command is talking to the speaker")
    }

    /// A read would wait for the connection to time out, and the menu
    /// already shows it isn't connected.
    @Test func itDoesNotReadWhileNotConnected() {
        let read = MenuOpenRead(isConnected: false, isExchangeInFlight: false, sourceByteAge: .seconds(30))
        #expect(read == .skipNotConnected)
        #expect(read.logLine == "menu opened: not reading the input, the speaker isn't connected")
    }

    @Test func aFewSecondsCountAsFresh() {
        #expect(MenuOpenRead.freshFor >= .seconds(2))
        #expect(MenuOpenRead.freshFor <= .seconds(5))
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

    @Test func theMenuOpenReadUsesTheControllersState() async throws {
        let clock = SimulatedClock()
        let mock = MockSpeakerConnection()
        mock.responses = [Self.reply(on)]
        let controller = SpeakerController(connection: mock, clock: clock)

        #expect(controller.menuOpenRead(isConnected: true) == .read(lastReadAgo: nil))
        _ = try await controller.getSourceByte()
        #expect(controller.menuOpenRead(isConnected: true) == .skipReadRecently(.zero))
        await clock.sleep(for: .seconds(4))
        #expect(controller.menuOpenRead(isConnected: true) == .read(lastReadAgo: .seconds(4)))
        #expect(controller.menuOpenRead(isConnected: false) == .skipNotConnected)
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
