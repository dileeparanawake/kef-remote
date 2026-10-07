import Foundation
import Testing
@testable import KEFRemoteCore

/// Hand test round 7: at the first launch the app looked for the speaker
/// before setup's permissions step, the search failed (Local Network was
/// off), and a "Discovery failed" HUD showed over the setup window.
/// Until setup is finished, the app's own searches wait for step 2,
/// which looks for the speaker as it shows.
struct SetupSearchTests {

    private let bySelf: [DiscoveryTrigger] = [.noIPSaved, .speakerUnreachable, .switchedToAuto, .localNetworkAllowed]
    private let clicks: [DiscoveryTrigger] = [.findSpeakerInMenu, .findSpeakerInSetup, .discoverInSettings]

    // MARK: - Searches the app starts by itself

    @Test func beforeStep2TheAppDoesNotSearchByItself() {
        for trigger in bySelf {
            #expect(SetupSearch.waits(trigger, isSetupFinished: false, findSpeakerStepShown: false), "\(trigger)")
        }
    }

    @Test func onceStep2HasShownItSearchesAsBefore() {
        for trigger in bySelf {
            #expect(!SetupSearch.waits(trigger, isSetupFinished: false, findSpeakerStepShown: true), "\(trigger)")
        }
    }

    @Test func onceSetupIsFinishedLaunchSearchesAsBefore() {
        for trigger in bySelf {
            #expect(!SetupSearch.waits(trigger, isSetupFinished: true, findSpeakerStepShown: false), "\(trigger)")
        }
    }

    /// He asked: a click always searches.
    @Test func aClickNeverWaits() {
        for trigger in clicks {
            #expect(!SetupSearch.waits(trigger, isSetupFinished: false, findSpeakerStepShown: false), "\(trigger)")
        }
    }

    @Test func theWaitIsLogged() {
        #expect(SetupSearch.waitLogLine(.noIPSaved)
            == "Not looking for the speaker by itself (no IP saved): setup isn't finished, and its step 2 looks when it shows")
    }

    // MARK: - Step 2 looks as it shows

    @Test func step2LooksInAutoWhenNothingAnswersYet() {
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .noSpeaker) == .search)
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .notConnected) == .search)
    }

    /// Manual never searches by itself: it waits for the IP he types.
    @Test func step2InManualWaitsForTheIP() {
        #expect(FindSpeakerOnShow(discovery: .manual, connection: .noSpeaker) == .dontSearch("Manual: waiting for an IP"))
    }

    @Test func step2DoesNotLookWhenThereIsNoNeed() {
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .connected) == .dontSearch("already connected"))
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .searching) == .dontSearch("a search or check is running"))
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .connecting) == .dontSearch("a search or check is running"))
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .localNetworkBlocked)
            == .dontSearch("Local Network is blocked"))
        #expect(FindSpeakerOnShow(discovery: .auto, connection: .dormant) == .dontSearch("not on the home network yet"))
    }

    @Test func step2LogsWhatItDid() {
        #expect(FindSpeakerOnShow.search.logLine == "step 2 looks for the speaker as it shows (Auto, nothing answering yet)")
        #expect(FindSpeakerOnShow.dontSearch("already connected").logLine
            == "step 2 doesn't look for the speaker as it shows: already connected")
    }

    // MARK: - The HUD after a search in the background

    @Test func withSetupClosedAMissShowsTheHUD() {
        #expect(SetupSearch.hud(after: .notFound, setupOpen: false) == .error("Speaker not found"))
        #expect(SetupSearch.hud(after: .failed("sendto failed"), setupOpen: false) == .error("Discovery failed"))
    }

    /// Step 2 shows the result; a HUD over the window says it twice, and
    /// over step 1 it's about a search he didn't start.
    @Test func withSetupOpenNoHUD() {
        #expect(SetupSearch.hud(after: .notFound, setupOpen: true) == nil)
        #expect(SetupSearch.hud(after: .failed("sendto failed"), setupOpen: true) == nil)
    }

    @Test func aFindOrARunningSearchShowsNoHUD() {
        let lsx = AppConfig.SpeakerConfig(name: "LSX", lastKnownIp: "192.168.1.80")
        #expect(SetupSearch.hud(after: .found(lsx), setupOpen: false) == nil)
        #expect(SetupSearch.hud(after: .alreadyRunning, setupOpen: false) == nil)
    }
}
