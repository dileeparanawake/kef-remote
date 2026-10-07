import Testing
@testable import KEFRemoteCore

/// One shortcut press, one action: the burst from the 6 Oct hand test
/// (176 fires of one press in 18 ms) becomes one fire.
struct ShortcutRepeatFilterTests {

    @Test func theFirstPressFires() {
        var filter = ShortcutRepeatFilter()
        #expect(filter.verdict(for: .powerToggle, at: .seconds(10)) == .fire(repeatsDroppedBefore: 0))
    }

    /// The hand test: 176 fires, tens of microseconds apart.
    @Test func aBurstFromOnePressFiresOnce() {
        var filter = ShortcutRepeatFilter()
        let verdicts = (0..<176).map { filter.verdict(for: .powerToggle, at: .seconds(10) + .microseconds(40 * $0)) }
        #expect(verdicts.first == .fire(repeatsDroppedBefore: 0))
        #expect(verdicts.dropFirst() == ArraySlice((1..<176).map { ShortcutRepeatFilter.Verdict.repeatOfLastPress(count: $0) }))
    }

    /// A burst that keeps going stays dropped: the window runs from the
    /// last fire seen, not the first.
    @Test func aLongBurstStaysDropped() {
        var filter = ShortcutRepeatFilter()
        let step = ShortcutRepeatFilter.samePressWithin / 2
        _ = filter.verdict(for: .powerToggle, at: .zero)
        for n in 1...20 {
            #expect(filter.verdict(for: .powerToggle, at: step * n) == .repeatOfLastPress(count: n))
        }
    }

    /// A second press after the window fires, and says how many repeats
    /// of the last press were dropped, for the log.
    @Test func aNewPressAfterTheWindowFires() {
        var filter = ShortcutRepeatFilter()
        _ = filter.verdict(for: .powerToggle, at: .seconds(10))
        _ = filter.verdict(for: .powerToggle, at: .seconds(10) + .milliseconds(1))
        _ = filter.verdict(for: .powerToggle, at: .seconds(10) + .milliseconds(2))
        let later = Duration.seconds(10) + .milliseconds(2) + ShortcutRepeatFilter.samePressWithin
        #expect(filter.verdict(for: .powerToggle, at: later) == .fire(repeatsDroppedBefore: 2))
        #expect(filter.verdict(for: .powerToggle, at: later + .seconds(5)) == .fire(repeatsDroppedBefore: 0))
    }

    /// Each action has its own window: volume up right after power still fires.
    @Test func otherActionsAreNotRepeats() {
        var filter = ShortcutRepeatFilter()
        _ = filter.verdict(for: .powerToggle, at: .seconds(10))
        #expect(filter.verdict(for: .volumeUp, at: .seconds(10) + .milliseconds(1)) == .fire(repeatsDroppedBefore: 0))
    }

    /// A person pressing again, about as fast as a key can be tapped, fires.
    @Test func aQuickSecondPressFires() {
        var filter = ShortcutRepeatFilter()
        _ = filter.verdict(for: .volumeUp, at: .seconds(10))
        #expect(filter.verdict(for: .volumeUp, at: .seconds(10) + .milliseconds(150)) == .fire(repeatsDroppedBefore: 0))
    }
}
