import Foundation

/// A macOS permission KEF Remote needs, and where to allow it.
///
/// ```
/// Accessibility   so the volume keys reach the speaker   (CGEvent tap)
/// Local Network   so the app can find the speaker        (SSDP and TCP)
/// ```
public enum Permission: String, CaseIterable, Sendable {
    case accessibility
    case localNetwork

    /// The name System Settings uses for it.
    public var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .localNetwork: return "Local Network"
        }
    }

    /// What it's for, in one line.
    public var purpose: String {
        switch self {
        case .accessibility: return "So the volume keys reach the speaker."
        case .localNetwork: return "So the app can find the speaker."
        }
    }

    /// Where it lives in System Settings, for someone finding it by hand.
    public var settingsPath: String { "Privacy & Security > \(title)" }

    /// Opens its pane in System Settings.
    ///
    /// Uses the legacy pane ID, `com.apple.preference.security`, which
    /// works on macOS 14, 15 and 26+. From macOS 13 the pane is an
    /// extension (`com.apple.settings.PrivacySecurity.extension`) whose
    /// Info.plist declares the old ID as its `legacyBundleIdentifier`,
    /// so `x-apple.systempreferences:` links to it still resolve (checked
    /// on macOS 27; the list of IDs in use is at
    /// https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751).
    ///
    /// The anchor picks the row. `Privacy_Accessibility` is a known
    /// anchor. Apple publishes no anchor for Local Network, and none is
    /// in the extension's list of anchors (`TCCServiceList.plist`), so
    /// `Privacy_LocalNetwork` may only open Privacy & Security; the guide
    /// shows ``settingsPath`` beside the button for that case.
    public var settingsURL: URL {
        let anchor: String
        switch self {
        case .accessibility: anchor = "Privacy_Accessibility"
        case .localNetwork: anchor = "Privacy_LocalNetwork"
        }
        // Force-unwrapped: built from constants, and the tests check each one.
        return URL(string: "\(Self.privacyPaneURL)?\(anchor)")!
    }

    static let privacyPaneURL = "x-apple.systempreferences:com.apple.preference.security"
}
