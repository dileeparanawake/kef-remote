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
/// Skip for now clicked on step 1
/// step 2 Find your speaker shown (allSteps)
/// Find speaker clicked
/// Find speaker result: No KEF speaker answered
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

    init(permissions: PermissionsModel, settings: SettingsModel, menuBar: MenuBarModel, actions: OnboardingActions) {
        self.permissions = permissions
        self.settings = settings
        self.menuBar = menuBar
        self.actions = actions
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
        if mode == .allSteps { allStepsLeftOn = newStep }
        log.info("step \(newStep.number) \(newStep.title) shown (\(mode.rawValue))")
    }

    var canContinue: Bool {
        step.canContinue(
            accessibility: permissions.accessibility,
            localNetwork: permissions.localNetwork,
            connection: menuBar.status
        )
    }

    func continueClicked() {
        log.info("Continue clicked on step \(step.number)")
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
