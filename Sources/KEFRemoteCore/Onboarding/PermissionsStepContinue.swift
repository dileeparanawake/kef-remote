/// Setup step 1's main button, once both permissions are ticked.
///
/// Hand test round 6: after he allowed the permissions, nothing said to
/// restart, so finding the speaker and the volume keys might not start
/// cleanly. A permission allowed during this run gets a restart first;
/// setup then reopens on step 2 (``Onboarding/windowAtLaunch(isFinished:resumeAtFindSpeaker:accessibility:)``).
///
/// ```
/// both ticked, one allowed during this run   [Restart and continue]
///   "Both allowed. KEF Remote restarts once so they take effect, then setup carries on."
/// both allowed before this run               [Continue]
/// not both ticked yet                        [Continue] greyed out
/// ```
///
/// The line replaces ``VolumeKeysLine`` and its Restart KEF Remote
/// button on step 1 of setup, so there is one restart, not two.
public enum PermissionsStepContinue: Equatable, Sendable {
    case continueToNextStep
    /// The permissions he allowed during this run, in the guide's order.
    case restartAndContinue(grantedThisRun: [Permission])

    public init(
        accessibility: PermissionStatus,
        localNetwork: PermissionStatus,
        grantedThisRun: PermissionsGrantedThisRun
    ) {
        let bothAllowed = accessibility == .granted && localNetwork == .granted
        let granted = Permission.allCases.filter { grantedThisRun.permissions.contains($0) }
        self = bothAllowed && !granted.isEmpty ? .restartAndContinue(grantedThisRun: granted) : .continueToNextStep
    }

    public var title: String {
        switch self {
        case .continueToNextStep: "Continue"
        case .restartAndContinue: "Restart and continue"
        }
    }

    /// Under the permissions, in place of ``VolumeKeysLine``; nil keeps
    /// that line.
    public var line: String? {
        switch self {
        case .continueToNextStep: nil
        case .restartAndContinue: "Both allowed. KEF Remote restarts once so they take effect, then setup carries on."
        }
    }

    /// One line under `onboarding` when he clicks it.
    public var clickLogLine: String {
        switch self {
        case .continueToNextStep:
            return "Continue clicked on step 1: both permissions were allowed before this run, no restart"
        case .restartAndContinue(let granted):
            let names = granted.map(\.title).joined(separator: ", ")
            return "Restart and continue clicked on step 1 (allowed during this run: \(names)): "
                + "restarting, setup reopens on step 2"
        }
    }
}
