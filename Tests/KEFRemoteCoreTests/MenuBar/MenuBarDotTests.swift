import Testing
@testable import KEFRemoteCore

/// Live test, 5 Oct: "when it's connected to the speaker or found the
/// speaker maybe we could have a green dot that just appears and then goes".
/// Round 3 the same day: the green dot stays longer, and finding the
/// speaker keeps the speaker icon with a pulsing orange dot.
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

    /// Round 3: 2 s went before he saw it.
    @Test func theGreenDotStaysAboutFourSeconds() {
        #expect(ConnectedFlash.duration == .seconds(4))
    }

    // MARK: - Which dot shows

    @Test func connectedWhileFlashingShowsTheGreenDot() {
        #expect(dot(.connected, flashing: true) == .justConnected)
    }

    @Test func connectedAfterTheFlashShowsNoDot() {
        #expect(dot(.connected, flashing: false) == .none)
    }

    /// If it drops within the 4 s, the flash must not hide the red dot.
    @Test func theRedDotWinsOverAStaleFlash() {
        for status in [ConnectionStatus.notConnected, .noSpeaker, .localNetworkBlocked] {
            #expect(dot(status, flashing: true) == .needsAttention, "\(status)")
            #expect(dot(status, flashing: false) == .needsAttention, "\(status)")
        }
    }

    @Test func statesThatSortThemselvesOutShowNoDotEvenMidFlash() {
        for status in [ConnectionStatus.connecting, .dormant] {
            #expect(dot(status, flashing: true) == .none, "\(status)")
        }
    }

    // MARK: - Orange dot while finding the speaker

    @Test func findingTheSpeakerShowsTheOrangeDot() {
        #expect(dot(.searching, flashing: false) == .searching)
        #expect(dot(.searching, flashing: true) == .searching)
    }

    @Test func onlyTheOrangeDotPulses() {
        #expect(MenuBarDot.searching.pulses)
        for still in [MenuBarDot.none, .needsAttention, .justConnected] {
            #expect(!still.pulses, "\(still)")
        }
    }

    // MARK: - The pulse

    @Test func thePulseTakesAboutASecond() {
        #expect(SearchingPulse.period == .seconds(1))
    }

    /// It starts full, so the dot is seen the moment finding starts.
    @Test func thePulseStartsAtFullStrength() {
        #expect(SearchingPulse.opacity(after: .zero) == SearchingPulse.brightestOpacity)
    }

    @Test func thePulseIsDimmestHalfwayAndFullAgainAfterOnePeriod() {
        let half = SearchingPulse.opacity(after: SearchingPulse.period / 2)
        let whole = SearchingPulse.opacity(after: SearchingPulse.period)
        #expect(abs(half - SearchingPulse.dimmestOpacity) < 0.0001)
        #expect(abs(whole - SearchingPulse.brightestOpacity) < 0.0001)
    }

    /// Never fades out completely, so the dot is always there to see.
    @Test func thePulseStaysBetweenDimmestAndFull() {
        #expect(SearchingPulse.dimmestOpacity > 0)
        for step in 0...40 {
            let opacity = SearchingPulse.opacity(after: .milliseconds(step * 73))
            #expect(opacity >= SearchingPulse.dimmestOpacity - 0.0001, "step \(step)")
            #expect(opacity <= SearchingPulse.brightestOpacity + 0.0001, "step \(step)")
        }
    }

    /// Redraws often enough to look smooth, but well below the pulse itself.
    @Test func thePulseRedrawsManyTimesAPeriod() {
        let framesPerPeriod = SearchingPulse.period / SearchingPulse.frameInterval
        #expect(framesPerPeriod >= 10)
        #expect(framesPerPeriod <= 30)
    }
}
