import Testing
@testable import KEFRemoteCore

/// Live test, 5 Oct: "when it's connected to the speaker or found the
/// speaker maybe we could have a green dot that just appears and then goes".
struct MenuBarDotTests {

    private func dot(_ status: ConnectionStatus, flashing: Bool) -> MenuBarDot {
        MenuBarPresentation(status: status, speakerName: "LSX", ip: "192.168.1.80", isFlashingConnected: flashing).dot
    }

    // MARK: - When the green flash starts

    @Test func becomingConnectedFromAnyOtherStateStartsTheFlash() {
        let others: [ConnectionStatus] = [.dormant, .noSpeaker, .searching, .connecting, .notConnected, .localNetworkBlocked]
        for old in others {
            #expect(ConnectedFlash.starts(from: old, to: .connected), "\(old)")
        }
    }

    /// Every command's reply says connected again; only a change flashes.
    @Test func stayingConnectedDoesNotFlash() {
        #expect(!ConnectedFlash.starts(from: .connected, to: .connected))
    }

    @Test func leavingConnectedDoesNotFlash() {
        for new in [ConnectionStatus.notConnected, .connecting, .searching, .dormant] {
            #expect(!ConnectedFlash.starts(from: .connected, to: new), "\(new)")
        }
    }

    @Test func theFlashIsBrief() {
        #expect(ConnectedFlash.duration == .seconds(2))
    }

    // MARK: - Which dot shows

    @Test func connectedWhileFlashingShowsTheGreenDot() {
        #expect(dot(.connected, flashing: true) == .justConnected)
    }

    @Test func connectedAfterTheFlashShowsNoDot() {
        #expect(dot(.connected, flashing: false) == .none)
    }

    /// If it drops within the 2 s, the flash must not hide the red dot.
    @Test func theRedDotWinsOverAStaleFlash() {
        for status in [ConnectionStatus.notConnected, .noSpeaker, .localNetworkBlocked] {
            #expect(dot(status, flashing: true) == .needsAttention, "\(status)")
            #expect(dot(status, flashing: false) == .needsAttention, "\(status)")
        }
    }

    @Test func statesThatSortThemselvesOutShowNoDotEvenMidFlash() {
        for status in [ConnectionStatus.connecting, .searching, .dormant] {
            #expect(dot(status, flashing: true) == .none, "\(status)")
        }
    }
}
