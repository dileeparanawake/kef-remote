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

    /// Where to find it in System Settings on this Mac, shown under the
    /// row in case Open Settings stops short of it.
    public var settingsHint: String {
        settingsHint(onMacOS: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    /// The hint on a given major version of macOS.
    ///
    /// macOS 27 calls the Accessibility row "Device Control and Data
    /// Access" (the pane's `ACCESSIBILITY` string in `Localizable.loctable`).
    /// Local Network has no anchor (see ``settingsURL``), so its hint is
    /// the click still to make.
    func settingsHint(onMacOS major: Int) -> String {
        switch self {
        case .accessibility:
            let row = major >= Self.firstMacOSWithDeviceControlRow ? "Device Control and Data Access" : title
            return "Privacy & Security > \(row)"
        case .localNetwork:
            return "In Privacy & Security, click Local Network, then turn on KEF Remote"
        }
    }

    /// macOS 27 renamed the Accessibility row.
    static let firstMacOSWithDeviceControlRow = 27

    /// Opens its pane in System Settings.
    ///
    /// Uses the pane's extension ID, `com.apple.settings.PrivacySecurity.extension`,
    /// on every macOS the app runs on (14+). The pane has been an
    /// extension since macOS 13, and the extension ID with
    /// `?Privacy_Accessibility` is what current apps use, e.g. Petal
    /// (github.com/Aayush9029/petal, AccessibilitySettingsGuide.swift)
    /// and Writing Tools (github.com/theJayTea/WritingTools); the
    /// Ventura+ list of pane IDs and anchors is at
    /// https://github.com/bvanpeski/SystemPreferences/blob/main/macos_preferencepanes-Ventura.md.
    /// The legacy ID, `com.apple.preference.security` (still in Rectangle
    /// and AltTab), opened only the top of Privacy & Security on macOS 27
    /// in the 6 Oct hand test.
    ///
    /// The anchor picks the row. The pane lists `Privacy_Accessibility`
    /// among its search terms, but no Local Network anchor (checked on
    /// macOS 27; Apple's DTS points only to the published schemes,
    /// https://developer.apple.com/forums/thread/763476), so Local Network
    /// opens Privacy & Security and ``settingsHint`` says what to click.
    public var settingsURL: URL {
        switch self {
        case .accessibility: return Self.privacyPaneURL(anchor: "Privacy_Accessibility")
        case .localNetwork: return Self.privacyPaneURL(anchor: nil)
        }
    }

    static let privacyPaneID = "com.apple.settings.PrivacySecurity.extension"

    private static func privacyPaneURL(anchor: String?) -> URL {
        let pane = "x-apple.systempreferences:\(privacyPaneID)"
        // Force-unwrapped: built from constants, and the tests check each one.
        return URL(string: anchor.map { "\(pane)?\($0)" } ?? pane)!
    }
}
