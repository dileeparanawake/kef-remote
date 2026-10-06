import Testing
@testable import KEFRemoteCore

/// What each way into the setup window opens: Finish setup…,
/// Permissions…, and the app opened again (the Dock icon).
struct SetupWindowOpeningTests {

    // MARK: - Finish setup… in the menu

    @Test func theMenuOffersFinishSetupUntilSetupIsFinished() {
        #expect(Onboarding.finishSetupItem(isFinished: false) == "Finish setup…")
        #expect(Onboarding.finishSetupItem(isFinished: true) == nil)
    }

    /// Hand test round 3: the window went behind another app's and he
    /// couldn't see how to get it back. Finish setup… goes back to where
    /// he was, not to step 1.
    @Test func finishSetupResumesWhereHeLeftIt() {
        let opening = SetupWindowOpening.resumeAllSteps
        #expect(opening.mode == .allSteps)
        #expect(opening.step(leftOn: .findSpeaker) == .findSpeaker)
        #expect(opening.step(leftOn: .done) == .done)
    }

    // MARK: - Permissions…

    @Test func onceSetupIsFinishedPermissionsOpensStepOneOnly() {
        #expect(Onboarding.permissionsItemOpens(isFinished: true, allStepsShowing: false) == .permissionsOnly)
        #expect(Onboarding.permissionsItemOpens(isFinished: true, allStepsShowing: true) == .permissionsOnly)
    }

    @Test func beforeSetupIsFinishedPermissionsOpensStepOneOnlyWhenSetupIsClosed() {
        #expect(Onboarding.permissionsItemOpens(isFinished: false, allStepsShowing: false) == .permissionsOnly)
    }

    /// Rather than dropping the steps he's part-way through.
    @Test func permissionsWhileSetupIsShowingGoesBackToItsStepOne() {
        let opening = Onboarding.permissionsItemOpens(isFinished: false, allStepsShowing: true)
        #expect(opening == .allStepsAtPermissions)
        #expect(opening.mode == .allSteps)
        #expect(opening.step(leftOn: .findSpeaker) == .permissions)
    }

    @Test func stepOneOnlyAlwaysStartsOnStepOne() {
        #expect(SetupWindowOpening.permissionsOnly.mode == .permissionsOnly)
        #expect(SetupWindowOpening.permissionsOnly.step(leftOn: .done) == .permissions)
    }

    // MARK: - Opened again: the Dock icon, or a second launch

    @Test func openingTheAppAgainResumesSetupUntilItIsFinished() {
        #expect(Onboarding.reopenOpensSetup(isFinished: false))
        #expect(!Onboarding.reopenOpensSetup(isFinished: true))
    }
}
