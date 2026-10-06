import Testing
@testable import KEFRemoteCore

/// The three steps of the setup window, and what unlocks Continue on each.
struct OnboardingStepTests {

    // MARK: - The steps, in order

    @Test func threeStepsInOrder() {
        #expect(OnboardingStep.allCases == [.permissions, .findSpeaker, .done])
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3])
        #expect(OnboardingStep.allCases.map(\.title) == ["Permissions", "Find your speaker", "You're set"])
    }

    @Test func continueGoesToTheNextStep() {
        #expect(OnboardingStep.permissions.next == .findSpeaker)
        #expect(OnboardingStep.findSpeaker.next == .done)
        #expect(OnboardingStep.done.next == nil)
    }

    @Test func backGoesToThePreviousStep() {
        #expect(OnboardingStep.permissions.previous == nil)
        #expect(OnboardingStep.findSpeaker.previous == .permissions)
        #expect(OnboardingStep.done.previous == .findSpeaker)
    }

    // MARK: - Step 1: both permissions ticked

    @Test func permissionsContinueOnceBothAreTicked() {
        #expect(OnboardingStep.permissions.canContinue(accessibility: .granted, localNetwork: .granted, connection: .noSpeaker))
    }

    @Test(arguments: [
        (PermissionStatus.notGranted, PermissionStatus.granted),
        (.granted, .notCheckedYet),
        (.granted, .notGranted),
        (.notGranted, .notCheckedYet),
    ])
    func permissionsWaitWhileOneIsNotTicked(accessibility: PermissionStatus, localNetwork: PermissionStatus) {
        #expect(!OnboardingStep.permissions.canContinue(accessibility: accessibility, localNetwork: localNetwork, connection: .connected))
    }

    // MARK: - Step 2: the speaker answered

    @Test func findSpeakerContinuesOnceTheSpeakerAnswered() {
        #expect(OnboardingStep.findSpeaker.canContinue(accessibility: .notGranted, localNetwork: .granted, connection: .connected))
    }

    @Test(arguments: [
        ConnectionStatus.dormant, .noSpeaker, .searching, .connecting, .notConnected, .localNetworkBlocked,
    ])
    func findSpeakerWaitsUntilTheSpeakerAnswers(connection: ConnectionStatus) {
        #expect(!OnboardingStep.findSpeaker.canContinue(accessibility: .granted, localNetwork: .granted, connection: connection))
    }

    // MARK: - Step 3: Done always closes

    @Test func doneIsAlwaysAvailable() {
        #expect(OnboardingStep.done.canContinue(accessibility: .notGranted, localNetwork: .notGranted, connection: .notConnected))
    }

    // MARK: - Step 3's lines

    @Test func youreSetNamesTheModifierAndThePowerShortcut() {
        #expect(OnboardingStep.youreSetLines(modifier: "Control", powerShortcut: "Cmd+Shift+O") == [
            "Control + volume keys change the speaker.",
            "Cmd+Shift+O turns it on and off.",
            "Change anything from the menu bar icon.",
        ])
    }

    @Test func youreSetLeavesOutAPowerShortcutThatIsNotSet() {
        #expect(OnboardingStep.youreSetLines(modifier: "Option", powerShortcut: nil) == [
            "Option + volume keys change the speaker.",
            "Change anything from the menu bar icon.",
        ])
    }
}
