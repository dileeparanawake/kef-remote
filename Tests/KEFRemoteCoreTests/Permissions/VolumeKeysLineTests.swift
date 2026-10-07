import Testing
@testable import KEFRemoteCore

/// Setup step 1 says whether the volume keys are ready once Accessibility
/// is allowed, so he knows if a restart is needed (hand test round 5:
/// nothing said so, and he worried the keys wouldn't work).
struct VolumeKeysLineTests {

    // MARK: - The tap's state, from the app

    @Test func offTheHomeNetworkTheTapIsNotStarted() {
        #expect(MediaKeyTapState(isActive: false, isRunning: false) == .notStarted)
    }

    @Test func aTapThatStartedIsRunning() {
        #expect(MediaKeyTapState(isActive: true, isRunning: true) == .running)
    }

    /// The app tried, and macOS refused the tap.
    @Test func aTapThatDidNotStartWasRefused() {
        #expect(MediaKeyTapState(isActive: true, isRunning: false) == .refused)
    }

    // MARK: - The line

    @Test func aRunningTapSaysReady() {
        let line = VolumeKeysLine(accessibility: .granted, tap: .running)
        #expect(line == .ready)
        #expect(line?.text == "Volume keys ready ✓")
        #expect(line?.offersRestart == false)
    }

    /// Accessibility is allowed but macOS still refuses the tap: only a
    /// new process gets it.
    @Test func aRefusedTapOffersARestart() {
        let line = VolumeKeysLine(accessibility: .granted, tap: .refused)
        #expect(line == .needsRestart)
        #expect(line?.text == "The volume keys start after a restart.")
        #expect(line?.offersRestart == true)
    }

    /// Off the home network the app stops the keys on purpose, and a
    /// restart wouldn't help.
    @Test func offTheHomeNetworkItSaysWhenTheyStart() {
        let line = VolumeKeysLine(accessibility: .granted, tap: .notStarted)
        #expect(line == .startsOnHomeNetwork)
        #expect(line?.text == "The volume keys start on your home network.")
        #expect(line?.offersRestart == false)
    }

    /// Without Accessibility the row above already says what to do.
    @Test func withoutAccessibilityThereIsNoLine() {
        for tap in [MediaKeyTapState.notStarted, .running, .refused] {
            #expect(VolumeKeysLine(accessibility: .notGranted, tap: tap) == nil)
            #expect(VolumeKeysLine(accessibility: .notCheckedYet, tap: tap) == nil)
        }
    }
}
