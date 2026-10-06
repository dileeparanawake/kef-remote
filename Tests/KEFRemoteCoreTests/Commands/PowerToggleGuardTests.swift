import Testing
@testable import KEFRemoteCore

/// The rule for power toggles: one at a time, and none right after another.
struct PowerToggleGuardTests {

    @Test func theFirstToggleGoes() {
        var rule = PowerToggleGuard()
        #expect(rule.start(at: .seconds(10)) == nil)
    }

    @Test func aToggleWhileOneIsInFlightIsRefused() {
        var rule = PowerToggleGuard()
        _ = rule.start(at: .seconds(10))
        #expect(rule.start(at: .seconds(10) + .milliseconds(1)) == .inFlight)
    }

    @Test func aToggleRightAfterOneFinishedIsRefused() {
        var rule = PowerToggleGuard()
        _ = rule.start(at: .seconds(10))
        rule.finish(at: .seconds(11))
        #expect(rule.start(at: .seconds(11) + .milliseconds(200)) == .tooSoon(sinceLast: .milliseconds(200)))
    }

    @Test func aToggleAfterTheGapGoes() {
        var rule = PowerToggleGuard()
        _ = rule.start(at: .seconds(10))
        rule.finish(at: .seconds(11))
        #expect(rule.start(at: .seconds(11) + PowerToggleGuard.minimumGap) == nil)
    }

    /// A refused toggle changes nothing: the one in flight still finishes it.
    @Test func aRefusalDoesNotEndTheToggleInFlight() {
        var rule = PowerToggleGuard()
        _ = rule.start(at: .seconds(10))
        _ = rule.start(at: .seconds(10))
        #expect(rule.start(at: .seconds(10)) == .inFlight)
    }

    @Test func refusalsSayWhyInTheLog() {
        #expect(PowerToggleGuard.Refusal.inFlight.reason == "another power change is still going")
        #expect(PowerToggleGuard.Refusal.tooSoon(sinceLast: .milliseconds(200)).reason
            == "200 ms after the last one (needs 1000 ms)")
    }
}
