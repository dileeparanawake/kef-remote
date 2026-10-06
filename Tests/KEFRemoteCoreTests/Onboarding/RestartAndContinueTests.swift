import Foundation
import Testing
@testable import KEFRemoteCore

/// Hand test round 6: once both permissions were allowed during setup,
/// nothing said to restart, so discovery and the volume keys might not
/// start cleanly. Step 1's Continue becomes Restart and continue, and
/// setup reopens on step 2 after the restart.
struct RestartAndContinueTests {

    // MARK: - Which permissions were allowed during this run

    @Test func aPermissionSwitchedOnDuringThisRunCounts() {
        var granted = PermissionsGrantedThisRun()
        let counts = granted.note(.accessibility, from: .notGranted, to: .granted)
        #expect(counts)
        #expect(granted.permissions == [.accessibility])
    }

    /// Local Network starts unchecked: an answer from the speaker means
    /// it was allowed before this run, with no prompt in it.
    @Test func localNetworkFoundAllowedOnTheFirstCheckDoesNotCount() {
        var granted = PermissionsGrantedThisRun()
        let counts = granted.note(.localNetwork, from: .notCheckedYet, to: .granted)
        #expect(!counts)
        #expect(granted.permissions.isEmpty)
    }

    /// macOS blocked it, then he allowed it: the probe saw it change.
    @Test func localNetworkAllowedAfterBeingBlockedCounts() {
        var granted = PermissionsGrantedThisRun()
        let counts = granted.note(.localNetwork, from: .notGranted, to: .granted)
        #expect(counts)
        #expect(granted.permissions == [.localNetwork])
    }

    @Test func aChangeAwayFromGrantedOrNoChangeDoesNotCount() {
        var granted = PermissionsGrantedThisRun()
        let awayCounts = granted.note(.accessibility, from: .granted, to: .notGranted)
        #expect(!awayCounts)
        let sameCounts = granted.note(.accessibility, from: .granted, to: .granted)
        #expect(!sameCounts)
        #expect(granted.permissions.isEmpty)
    }

    /// Counted once: the log says so the first time only.
    @Test func aSecondGrantOfTheSamePermissionIsNotNew() {
        var granted = PermissionsGrantedThisRun()
        _ = granted.note(.accessibility, from: .notGranted, to: .granted)
        let countsAgain = granted.note(.accessibility, from: .notGranted, to: .granted)
        #expect(!countsAgain)
        #expect(granted.permissions == [.accessibility])
    }

    // MARK: - Step 1's main button

    @Test func bothAllowedWithOneAllowedDuringThisRunRestartsFirst() {
        var granted = PermissionsGrantedThisRun()
        _ = granted.note(.accessibility, from: .notGranted, to: .granted)
        let button = PermissionsStepContinue(accessibility: .granted, localNetwork: .granted, grantedThisRun: granted)
        #expect(button == .restartAndContinue(grantedThisRun: [.accessibility]))
        #expect(button.title == "Restart and continue")
        #expect(button.line == "Both allowed. KEF Remote restarts once so they take effect, then setup carries on.")
    }

    /// Nothing changed in this run, so nothing needs a restart.
    @Test func bothAllowedAtLaunchIsPlainContinue() {
        let button = PermissionsStepContinue(
            accessibility: .granted, localNetwork: .granted, grantedThisRun: PermissionsGrantedThisRun()
        )
        #expect(button == .continueToNextStep)
        #expect(button.title == "Continue")
        #expect(button.line == nil)
    }

    /// Continue is greyed out until both are ticked
    /// (``OnboardingStep/canContinue(accessibility:localNetwork:connection:)``);
    /// it doesn't offer a restart before then.
    @Test func untilBothAreAllowedItIsPlainContinue() {
        var granted = PermissionsGrantedThisRun()
        _ = granted.note(.accessibility, from: .notGranted, to: .granted)
        for localNetwork in [PermissionStatus.notGranted, .notCheckedYet] {
            let button = PermissionsStepContinue(accessibility: .granted, localNetwork: localNetwork, grantedThisRun: granted)
            #expect(button == .continueToNextStep)
        }
    }

    @Test func bothGrantedDuringThisRunAreNamedInOrder() {
        var granted = PermissionsGrantedThisRun()
        _ = granted.note(.localNetwork, from: .notGranted, to: .granted)
        _ = granted.note(.accessibility, from: .notGranted, to: .granted)
        let button = PermissionsStepContinue(accessibility: .granted, localNetwork: .granted, grantedThisRun: granted)
        #expect(button == .restartAndContinue(grantedThisRun: [.accessibility, .localNetwork]))
    }

    @Test func eachClickLogsWhy() {
        #expect(PermissionsStepContinue.continueToNextStep.clickLogLine
            == "Continue clicked on step 1: both permissions were allowed before this run, no restart")
        #expect(PermissionsStepContinue.restartAndContinue(grantedThisRun: [.accessibility, .localNetwork]).clickLogLine
            == "Restart and continue clicked on step 1 (allowed during this run: Accessibility, Local Network): "
            + "restarting, setup reopens on step 2")
    }

    // MARK: - Saved in config.json, so the new copy knows

    @Test func aNewConfigDoesNotResume() {
        #expect(AppConfig().onboarding?.resumeAtFindSpeaker == false)
    }

    /// A file from before this flag has only "finished".
    @Test func anOlderOnboardingBlockDoesNotResume() throws {
        let json = #"{"finished": false}"#.data(using: .utf8)!
        let onboarding = try JSONDecoder().decode(AppConfig.OnboardingConfig.self, from: json)
        #expect(onboarding == .init(finished: false))
        #expect(!onboarding.resumeAtFindSpeaker)
    }

    @Test func theResumeFlagIsSavedAndLoaded() throws {
        var config = AppConfig()
        config.onboarding = .init(finished: false, resumeAtFindSpeaker: true)
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        let filePath = testDir.appendingPathComponent("config.json")

        try AppConfig.save(config, to: filePath)

        #expect(try String(contentsOf: filePath, encoding: .utf8).contains("\"resumeAtFindSpeaker\" : true"))
        #expect(try AppConfig.load(from: filePath).onboarding?.resumeAtFindSpeaker == true)
    }

    /// Cleared once step 2 shows, so a later launch starts where he
    /// leaves it, not on step 2 again.
    @Test func showingStepTwoClearsTheFlag() {
        var onboarding = AppConfig.OnboardingConfig(finished: false, resumeAtFindSpeaker: true)
        let clearedOnStepOne = onboarding.clearResume(onShowing: .permissions)
        #expect(!clearedOnStepOne)
        #expect(onboarding.resumeAtFindSpeaker)
        let clearedOnStepTwo = onboarding.clearResume(onShowing: .findSpeaker)
        #expect(clearedOnStepTwo)
        #expect(!onboarding.resumeAtFindSpeaker)
        let clearedAgain = onboarding.clearResume(onShowing: .findSpeaker)
        #expect(!clearedAgain)
    }

    // MARK: - The launch after the restart

    @Test func afterTheRestartSetupOpensOnStepTwo() {
        let opening = Onboarding.windowAtLaunch(isFinished: false, resumeAtFindSpeaker: true, accessibility: .granted)
        #expect(opening == .afterRestart)
        #expect(opening?.mode == .allSteps)
        #expect(opening?.step(leftOn: .permissions) == .findSpeaker)
    }

    /// Finished setup wins: the flag is left over from an older run.
    @Test func onceFinishedTheFlagIsIgnored() {
        #expect(Onboarding.windowAtLaunch(isFinished: true, resumeAtFindSpeaker: true, accessibility: .granted) == nil)
        #expect(Onboarding.windowAtLaunch(isFinished: true, resumeAtFindSpeaker: true, accessibility: .notGranted)
            == .permissionsOnly)
    }
}
