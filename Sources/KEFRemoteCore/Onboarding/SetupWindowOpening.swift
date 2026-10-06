/// How the setup window opens, and which step it shows.
///
/// ```
/// way in                       setup not finished         setup finished
/// ───────────────────────────  ─────────────────────────  ───────────────
/// launch                       resumeAllSteps (step 1)    permissionsOnly, only while
///                                                         Accessibility is missing
/// launch after Restart and     afterRestart (step 2)      (as launch)
///   continue
/// Finish setup… (menu, first)  resumeAllSteps             (not in the menu)
/// Permissions… (menu)          permissionsOnly, or        permissionsOnly
///                              allStepsAtPermissions
///                              while the steps show
/// Dock icon / opened again     resumeAllSteps             Settings instead
/// ```
///
/// In hand test round 3 the window went behind another app's and it
/// wasn't clear how to get it back: Finish setup… and the Dock icon go
/// back to the step he was on.
public enum SetupWindowOpening: String, Equatable, Sendable {
    /// All the steps, on the step he left them (step 1 the first time).
    case resumeAllSteps
    /// All the steps, back on step 1: Permissions… while they show.
    case allStepsAtPermissions
    /// Step 1 on its own: the permissions guide.
    case permissionsOnly
    /// All the steps, on step 2: the launch after Restart and continue
    /// (``PermissionsStepContinue``). The permissions it restarted for
    /// are done.
    case afterRestart

    public var mode: OnboardingMode {
        self == .permissionsOnly ? .permissionsOnly : .allSteps
    }

    /// The step to show.
    ///
    /// - Parameter leftOn: The step last shown with all the steps.
    public func step(leftOn: OnboardingStep) -> OnboardingStep {
        switch self {
        case .resumeAllSteps: leftOn
        case .allStepsAtPermissions, .permissionsOnly: .permissions
        case .afterRestart: .findSpeaker
        }
    }
}

extension Onboarding {
    /// The menu's first item until setup is finished, or nil once it is.
    public static func finishSetupItem(isFinished: Bool) -> String? {
        isFinished ? nil : "Finish setup…"
    }

    /// What Permissions… in the menu opens.
    ///
    /// - Parameter allStepsShowing: The setup window is open on all the
    ///   steps. Then it goes back to their step 1, rather than dropping
    ///   the steps he's part-way through.
    public static func permissionsItemOpens(isFinished: Bool, allStepsShowing: Bool) -> SetupWindowOpening {
        !isFinished && allStepsShowing ? .allStepsAtPermissions : .permissionsOnly
    }

    /// Whether clicking the Dock icon, or opening the app again while it
    /// runs, opens setup (true) or Settings (false).
    public static func reopenOpensSetup(isFinished: Bool) -> Bool {
        !isFinished
    }
}
