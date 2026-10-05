import CoreGraphics
import Foundation

/// The modifier key held with a media key to send it to the speaker
/// instead of the Mac.
///
/// One source of truth for the choice: the settings picker writes it,
/// and `AppDelegate` reads it to configure ``MediaKeyInterceptor``.
/// Stored in `UserDefaults` under ``userDefaultsKey``.
enum MediaKeyModifier: String, CaseIterable {
    case shift
    case control
    case option
    case command

    /// Used when nothing is stored yet, or the stored value is unknown.
    static let defaultChoice: MediaKeyModifier = .control

    static let userDefaultsKey = "mediaKeyModifier"

    /// The saved choice, or ``defaultChoice``.
    static var stored: MediaKeyModifier {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return MediaKeyModifier(rawValue: raw) ?? defaultChoice
    }

    static func store(_ choice: MediaKeyModifier) {
        UserDefaults.standard.set(choice.rawValue, forKey: userDefaultsKey)
    }

    /// Label shown in the settings picker.
    var displayName: String {
        switch self {
        case .shift:   return "Shift"
        case .control: return "Control"
        case .option:  return "Option"
        case .command: return "Command"
        }
    }

    /// The event flag the interceptor checks for.
    var eventFlags: CGEventFlags {
        switch self {
        case .shift:   return .maskShift
        case .control: return .maskControl
        case .option:  return .maskAlternate
        case .command: return .maskCommand
        }
    }
}
