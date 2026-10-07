import Combine
import KEFRemoteCore

/// What the setup window can ask the app to do. `AppDelegate` fills these in.
struct OnboardingActions {
    /// Look for the speaker, as Find again in Settings does.
    var findSpeaker: () async -> DiscoveryOutcome
    /// Save `"onboarding": {"finished": true}`.
    var finish: () -> Void
    /// Quit and open again, so the volume keys start.
    var restart: () -> Void
    /// Save that setup goes on at step 2, then quit and open again
    /// (``PermissionsStepContinue``). False if the restart failed.
    var restartAndContinue: () -> Bool
    /// A step showed with all the steps: step 2 clears the resume flag.
    var stepShown: (OnboardingStep) -> Void
}

/// State for the setup window: which step, and each click.
///
/// The steps' rules live in ``OnboardingStep``; this only moves between
/// them. Step 1 reads ``PermissionsModel``. Step 2 sets Auto or Manual
/// and saves the IP through ``SettingsModel``, so Settings shows the
/// same; whether the speaker answered comes from ``MenuBarModel``.
///
/// Each step shown and each click logs one line under `onboarding`:
/// ```
/// step 1 Permissions shown (allSteps)
/// Restart and continue clicked on step 1 (allowed during this run: Accessibility): restarting, …
/// Skip for now clicked on step 1
/// step 2 Find your speaker shown (allSteps)
/// step 2 looks for the speaker as it shows (Auto, nothing answering yet)
/// Find speaker result: No KEF speaker answered
/// Find speaker clicked
/// Enter the IP instead clicked
/// Save clicked: 192.168.1.80
/// Continue clicked on step 2
/// step 3 You're set shown (allSteps)
/// Done clicked: setup finished
/// ```
@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var mode: OnboardingMode = .allSteps
    @Published private(set) var step: OnboardingStep = .permissions
    /// The last Find speaker here found nothing, and nothing has been
    /// tried since. Cleared by the next search, save or mode change.
    @Published private(set) var searchFoundNothing = false

    let permissions: PermissionsModel
    let settings: SettingsModel
    let menuBar: MenuBarModel
    /// Set by the window controller: Done closes the window.
    var onClose: (() -> Void)?

    private let actions: OnboardingActions
    private let log = AppLogger(subsystem: "com.kef-remote", category: "onboarding")

    /// Passes on each change to the models the steps read.
    private var sourcesWatch: AnyCancellable?

    init(permissions: PermissionsModel, settings: SettingsModel, menuBar: MenuBarModel, actions: OnboardingActions) {
        self.permissions = permissions
        self.settings = settings
        self.menuBar = menuBar
        self.actions = actions
        // Step 2's line, its Find speaker button and Continue are read
        // from this model but come from the others. SwiftUI redraws a
        // step only when a model it observes changes, so step 2 kept
        // "Connecting…" after the speaker answered (hand test round 7).
        // Any change to them is a change to this model too.
        sourcesWatch = Publishers.Merge3(
            permissions.objectWillChange, settings.objectWillChange, menuBar.objectWillChange
        )
        .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    /// The step last shown with all the steps, where Finish setup… goes back to.
    private var allStepsLeftOn: OnboardingStep = .permissions

    /// Show the steps ``SetupWindowOpening`` says, on its step.
    func open(_ opening: SetupWindowOpening) {
        mode = opening.mode
        // Going back to where he was keeps what the search last said.
        if opening != .resumeAllSteps { searchFoundNothing = false }
        go(to: opening.step(leftOn: allStepsLeftOn))
    }

    func go(to newStep: OnboardingStep) {
        step = newStep
        log.info("step \(newStep.number) \(newStep.title) shown (\(mode.rawValue))")
        if mode == .allSteps {
            allStepsLeftOn = newStep
            actions.stepShown(newStep)
            if newStep == .findSpeaker { lookOnShowingStep2() }
        }
    }

    /// Step 2 looks for the speaker as it shows, in Auto: the app's own
    /// launch search waited for it (``SetupSearch``).
    private func lookOnShowingStep2() {
        let onShow = FindSpeakerOnShow(discovery: settings.discovery, connection: menuBar.status)
        log.info(onShow.logLine)
        guard onShow == .search else { return }
        Task { await search() }
    }

    var canContinue: Bool {
        step.canContinue(
            accessibility: permissions.accessibility,
            localNetwork: permissions.localNetwork,
            connection: menuBar.status
        )
    }

    /// Step 1's main button: Continue, or Restart and continue when a
    /// permission was allowed during this run.
    var permissionsContinue: PermissionsStepContinue {
        PermissionsStepContinue(
            accessibility: permissions.accessibility,
            localNetwork: permissions.localNetwork,
            grantedThisRun: permissions.grantedThisRun
        )
    }

    /// The line under the permissions in place of the volume keys line,
    /// on step 1 of all the steps only: the permissions guide alone has
    /// no Continue.
    var permissionsRestartLine: String? {
        mode == .allSteps ? permissionsContinue.line : nil
    }

    var continueTitle: String {
        step == .permissions ? permissionsContinue.title : "Continue"
    }

    func continueClicked() {
        guard step == .permissions else {
            log.info("Continue clicked on step \(step.number)")
            if let next = step.next { go(to: next) }
            return
        }
        let button = permissionsContinue
        log.info(button.clickLogLine)
        if case .restartAndContinue = button, actions.restartAndContinue() { return }
        // Plain Continue, or a restart that failed: go on in this copy.
        if let next = step.next { go(to: next) }
    }

    func skipClicked() {
        log.info("Skip for now clicked on step \(step.number)")
        if let next = step.next { go(to: next) }
    }

    func backClicked() {
        log.info("Back clicked on step \(step.number)")
        if let previous = step.previous { go(to: previous) }
    }

    func doneClicked() {
        log.info("Done clicked: setup finished")
        actions.finish()
        onClose?()
    }

    func restartClicked() {
        log.info("Restart KEF Remote clicked")
        actions.restart()
    }

    // MARK: - Step 2

    var searchLine: SpeakerSearchLine {
        SpeakerSearchLine(
            connection: menuBar.status,
            speaker: AppConfig.SpeakerConfig(name: menuBar.speakerName, lastKnownIp: menuBar.speakerIP),
            searchFoundNothing: searchFoundNothing
        )
    }

    func setDiscovery(_ newMode: DiscoveryMode) {
        guard newMode != settings.discovery else { return }
        log.info("\(newMode == .auto ? "Auto" : "Manual") chosen")
        searchFoundNothing = false
        settings.setDiscovery(newMode)
    }

    /// From a search that found nothing: type the IP instead.
    func enterIPClicked() {
        log.info("Enter the IP instead clicked")
        searchFoundNothing = false
        settings.setDiscovery(.manual)
    }

    func findSpeaker() async {
        log.info("Find speaker clicked")
        await search()
    }

    /// Look for the speaker, from a click or as step 2 shows.
    private func search() async {
        searchFoundNothing = false
        let outcome = await actions.findSpeaker()
        switch outcome {
        case .notFound, .failed: searchFoundNothing = true
        case .found, .alreadyRunning: searchFoundNothing = false
        }
        log.info("Find speaker result: \(outcome.message)")
    }

    func saveIP() {
        log.info("Save clicked: \(settings.ipText)")
        searchFoundNothing = false
        settings.saveIP()
    }

    // MARK: - Step 3

    /// The modifier and power shortcut as set now, so the lines are true.
    var youreSetLines: [String] {
        OnboardingStep.youreSetLines(
            modifier: settings.modifier.displayName,
            powerShortcut: ShortcutAction.powerToggle.shortcutWords
        )
    }
}
