import Foundation
import Testing
@testable import KEFRemoteCore

/// Hand test round 7: during the Accessibility step his Mac stopped
/// taking clicks and he had to restart it. Open Settings showed the
/// macOS Accessibility prompt, a system dialog, while the setup window
/// kept pulling itself to the front. Now the app leaves its windows
/// where they are for a while after the prompt, and tries a set number
/// of times to come to the front.
struct WindowFrontTests {

    private let start = ContinuousClock.now

    // MARK: - After the macOS prompt

    @Test func withNoPromptAWindowMayComeToTheFront() {
        #expect(WindowFront.mayPullToFront(now: start, systemPromptAt: nil))
    }

    @Test func justAfterThePromptNoWindowIsPulledOverIt() {
        #expect(!WindowFront.mayPullToFront(now: start, systemPromptAt: start))
        #expect(!WindowFront.mayPullToFront(now: start + .seconds(9), systemPromptAt: start))
    }

    @Test func tenSecondsLaterWindowsComeToTheFrontAgain() {
        #expect(WindowFront.holdBackAfterSystemPrompt == .seconds(10))
        #expect(WindowFront.mayPullToFront(now: start + .seconds(10), systemPromptAt: start))
    }

    // MARK: - Trying again, a set number of times

    @Test func inFrontNeedsNothing() {
        #expect(WindowFront.afterCheck(isInFront: true, triesSoFar: 0, mayPull: true) == .inFront)
    }

    @Test func notInFrontTriesAgainTwiceThenStops() {
        #expect(WindowFront.maxTriesAgain == 2)
        #expect(WindowFront.afterCheck(isInFront: false, triesSoFar: 0, mayPull: true) == .tryAgain(1))
        #expect(WindowFront.afterCheck(isInFront: false, triesSoFar: 1, mayPull: true) == .tryAgain(2))
        #expect(WindowFront.afterCheck(isInFront: false, triesSoFar: 2, mayPull: true) == .giveUp(2))
    }

    @Test func whileHeldBackItDoesNotTryAgain() {
        #expect(WindowFront.afterCheck(isInFront: false, triesSoFar: 0, mayPull: false) == .holdBack)
    }

    @Test func eachCheckLogsOneLine() {
        #expect(WindowFront.AfterCheck.tryAgain(1).logLine(window: "setup") == "setup not in front: trying again (1 of 2)")
        #expect(WindowFront.AfterCheck.giveUp(2).logLine(window: "setup")
            == "setup not in front after 2 tries: leaving it (its Dock icon brings it back)")
        #expect(WindowFront.AfterCheck.holdBack.logLine(window: "setup")
            == "setup not in front: not pulling it over the macOS prompt")
        #expect(WindowFront.AfterCheck.inFront.logLine(window: "setup") == nil)
    }
}
