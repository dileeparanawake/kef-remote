/// The steps of the setup window, the first time KEF Remote opens.
///
/// ```
/// 1 Permissions          2 Find your speaker        3 You're set
/// ✓ Accessibility        (•) Auto  ( ) Manual       Control + volume keys
/// ✓ Local Network        [Find speaker]             change the speaker.
///                        ✓ Found LSX at …           Cmd+Shift+O turns it…
/// Skip for now [Continue]  Back [Continue]          [Done]
/// ```
///
/// Step 1's Continue is Restart and continue when he allowed a permission
/// during this run (``PermissionsStepContinue``).
///
/// Continue unlocks when the step is done (``canContinue(accessibility:localNetwork:connection:)``).
/// Each way into the window, and the step it opens on: ``SetupWindowOpening``.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case permissions = 1
    case findSpeaker
    case done

    /// 1, 2 or 3, as the window counts them.
    public var number: Int { rawValue }

    public var title: String {
        switch self {
        case .permissions: return "Permissions"
        case .findSpeaker: return "Find your speaker"
        case .done: return "You're set"
        }
    }

    /// Where Continue goes. Nil on the last step, where Done closes.
    public var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }

    /// Where Back goes. Nil on the first step.
    public var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// Whether Continue (Done, on the last step) is enabled.
    ///
    /// Step 1 waits for both ticks; Skip for now is the way past without
    /// them. Step 2 waits for the speaker to answer, so step 3's promise
    /// holds.
    public func canContinue(
        accessibility: PermissionStatus,
        localNetwork: PermissionStatus,
        connection: ConnectionStatus
    ) -> Bool {
        switch self {
        case .permissions: return accessibility == .granted && localNetwork == .granted
        case .findSpeaker: return connection == .connected
        case .done: return true
        }
    }

    /// What step 3 says works now, and where to change it.
    ///
    /// - Parameters:
    ///   - modifier: The media key modifier's name, such as "Control".
    ///   - powerShortcut: The power on/off shortcut in words, or nil
    ///     when he has cleared it: then the line would be untrue.
    public static func youreSetLines(modifier: String, powerShortcut: String?) -> [String] {
        var lines = ["\(modifier) + volume keys change the speaker."]
        if let powerShortcut {
            lines.append("\(powerShortcut) turns it on and off.")
        }
        lines.append("Change anything from the menu bar icon.")
        return lines
    }
}

/// What the setup window shows.
public enum OnboardingMode: String, Sendable {
    /// All three steps, until onboarding is finished.
    case allSteps
    /// Step 1 alone: Permissions… in the menu, or a later launch with
    /// Accessibility missing.
    case permissionsOnly
}

/// Whether onboarding is finished, and what opens at launch.
public enum Onboarding {
    /// Whether he has been through setup.
    ///
    /// - Parameter saved: `"onboarding"` from config.json. A file written
    ///   before onboarding existed has none. Someone using that file who
    ///   has a speaker saved and Accessibility allowed has set up by hand
    ///   already, so counts as finished and isn't walked through it
    ///   again; anyone else hasn't got that far, so sees all the steps.
    public static func isFinished(
        saved: AppConfig.OnboardingConfig?,
        speaker: AppConfig.SpeakerConfig?,
        accessibility: PermissionStatus
    ) -> Bool {
        if let saved { return saved.finished }
        let hasSpeaker = !(speaker?.lastKnownIp ?? "").isEmpty
        return hasSpeaker && accessibility == .granted
    }

    /// The window that opens at launch, or nil for none. Once finished,
    /// only step 1 opens, and only while the volume keys can't work
    /// (``PermissionsGuide/showsAtLaunch(accessibility:)``).
    ///
    /// - Parameter resumeAtFindSpeaker: Restart and continue restarted
    ///   the app (``PermissionsStepContinue``): setup goes on at step 2.
    public static func windowAtLaunch(
        isFinished: Bool, resumeAtFindSpeaker: Bool, accessibility: PermissionStatus
    ) -> SetupWindowOpening? {
        guard isFinished else { return resumeAtFindSpeaker ? .afterRestart : .resumeAllSteps }
        return PermissionsGuide.showsAtLaunch(accessibility: accessibility) ? .permissionsOnly : nil
    }
}
