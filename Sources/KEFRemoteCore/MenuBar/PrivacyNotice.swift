import Foundation

/// The privacy notice: KEF Remote collects nothing. A sibling of
/// ``MenuLink`` that stays out of the menu (it's long enough), and shows
/// in two quiet places instead:
///
/// ```
/// Settings, at the foot:   Privacy: KEF Remote collects nothing
/// Setup, step 3:           Privacy
/// ```
public enum PrivacyNotice {
    /// PRIVACY.md on the repo's main branch, so a fix to the notice
    /// reaches every copy of the app without a new build.
    public static let url = URL(string: "https://github.com/dileeparanawake/kef-remote/blob/main/PRIVACY.md")!

    /// The footer link in Settings: the answer, so most people needn't click.
    public static let settingsTitle = "Privacy: KEF Remote collects nothing"

    /// The link on setup's last step, kept to one word so it stays quiet.
    public static let setupTitle = "Privacy"
}
