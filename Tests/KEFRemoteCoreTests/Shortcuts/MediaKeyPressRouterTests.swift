import Testing
@testable import KEFRemoteCore

/// Both halves of a media key press go the same way: to the speaker, or
/// to the Mac. The key-down decides.
struct MediaKeyPressRouterTests {
    let mute = 7
    let volumeUp = 0

    @Test func withTheModifierBothHalvesAreKeptAndTheKeyUpSends() {
        var router = MediaKeyPressRouter()
        #expect(router.route(keyCode: mute, isKeyUp: false, modifierHeld: true) == .keep)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: true) == .keepAndSend)
    }

    @Test func withoutTheModifierBothHalvesGoToTheMac() {
        var router = MediaKeyPressRouter()
        #expect(router.route(keyCode: mute, isKeyUp: false, modifierHeld: false) == .toMac)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: false) == .toMac)
    }

    /// The 6 Oct hand test: a key-down that reached the Mac before Control
    /// did, and a key-up sent to the speaker, did both (Control + play/pause
    /// showed the HUD and opened Apple Music). Now the key-up follows its
    /// key-down to the Mac, and nothing is sent.
    @Test func aKeyDownThatWentToTheMacTakesItsKeyUpWithIt() {
        var router = MediaKeyPressRouter()
        #expect(router.route(keyCode: mute, isKeyUp: false, modifierHeld: false) == .toMac)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: true) == .toMac)
    }

    /// Letting go of Control a moment before the key still sends: the
    /// key-down was kept, so the Mac never saw this press.
    @Test func releasingTheModifierFirstStillSends() {
        var router = MediaKeyPressRouter()
        #expect(router.route(keyCode: mute, isKeyUp: false, modifierHeld: true) == .keep)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: false) == .keepAndSend)
    }

    /// A held volume key repeats its key-down; the key-up sends once.
    @Test func aHeldKeySendsOnce() {
        var router = MediaKeyPressRouter()
        for _ in 0..<5 {
            #expect(router.route(keyCode: volumeUp, isKeyUp: false, modifierHeld: true) == .keep)
        }
        #expect(router.route(keyCode: volumeUp, isKeyUp: true, modifierHeld: true) == .keepAndSend)
    }

    /// A key-up with no key-down seen (the tap started mid-press) goes by
    /// the modifier, as before.
    @Test func aKeyUpWithNoKeyDownGoesByTheModifier() {
        var router = MediaKeyPressRouter()
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: true) == .keepAndSend)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: false) == .toMac)
    }

    /// Each press starts fresh: one that went to the Mac doesn't change the next.
    @Test func theNextPressDecidesAgain() {
        var router = MediaKeyPressRouter()
        _ = router.route(keyCode: mute, isKeyUp: false, modifierHeld: false)
        _ = router.route(keyCode: mute, isKeyUp: true, modifierHeld: false)
        #expect(router.route(keyCode: mute, isKeyUp: false, modifierHeld: true) == .keep)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: true) == .keepAndSend)
    }

    /// Two keys at once each follow their own key-down.
    @Test func eachKeyFollowsItsOwnKeyDown() {
        var router = MediaKeyPressRouter()
        _ = router.route(keyCode: mute, isKeyUp: false, modifierHeld: false)
        _ = router.route(keyCode: volumeUp, isKeyUp: false, modifierHeld: true)
        #expect(router.route(keyCode: volumeUp, isKeyUp: true, modifierHeld: true) == .keepAndSend)
        #expect(router.route(keyCode: mute, isKeyUp: true, modifierHeld: true) == .toMac)
    }

    @Test func routesReadPlainlyInTheLog() {
        #expect("\(MediaKeyPressRouter.Route.toMac)" == "to the Mac")
        #expect("\(MediaKeyPressRouter.Route.keep)" == "kept")
        #expect("\(MediaKeyPressRouter.Route.keepAndSend)" == "kept, sent to the speaker")
    }
}
