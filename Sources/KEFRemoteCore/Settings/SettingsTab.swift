import Foundation

/// The tabs of the Settings window. All of it in one window was taller
/// than a 13-inch MacBook's screen once the shortcut rows came in (hand
/// test round 5), so each tab holds one part:
///
/// ```
/// [ Speaker ]  [ Keys ]  [ About ]
///   Speaker:  Connection (discovery, the speaker found), Speaker (its settings)
///   Keys:     Modifier, the shortcut recorders
///   About:    Version, Made by Dileepa, Send feedback…, Privacy
/// ```
public enum SettingsTab: String, CaseIterable, Sendable {
    case speaker
    case keys
    case about

    /// The tab Settings opens on.
    public static let first: SettingsTab = .speaker

    /// The tallest a tab's content grows before it scrolls. A 13-inch
    /// MacBook Air shows about 800 pt under the menu bar; with the title
    /// bar and tab bar on top, the window stays under about 600 pt.
    public static let maxContentHeight: Double = 520

    public var title: String {
        switch self {
        case .speaker: "Speaker"
        case .keys: "Keys"
        case .about: "About"
        }
    }

    /// The SF Symbol beside the title.
    public var systemImage: String {
        switch self {
        case .speaker: "hifispeaker"
        case .keys: "keyboard"
        case .about: "info.circle"
        }
    }
}
