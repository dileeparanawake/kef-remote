import Foundation

/// One row of the permissions guide, as the window shows it.
///
/// ```
/// Accessibility                              ✓ Allowed
/// So the volume keys reach the speaker.      [Open Settings]
/// ```
///
/// The status is a symbol as well as words, so it reads without colour.
public struct PermissionRow: Equatable, Sendable {
    public let permission: Permission
    public let status: PermissionStatus

    public init(_ permission: Permission, status: PermissionStatus) {
        self.permission = permission
        self.status = status
    }

    public var title: String { permission.title }
    public var purpose: String { permission.purpose }
    public var settingsPath: String { permission.settingsPath }

    /// Red in the window: he has to do something.
    public var needsAttention: Bool { status == .notGranted }

    /// An SF Symbol: a tick, a cross, or a question mark.
    public var statusSymbol: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .notGranted: return "xmark.circle.fill"
        case .notCheckedYet: return "questionmark.circle"
        }
    }

    public var statusText: String {
        switch (status, permission) {
        case (.granted, _): return "Allowed"
        case (.notGranted, .accessibility): return "Not allowed yet"
        case (.notGranted, .localNetwork): return "Blocked: the app can't reach the speaker"
        case (.notCheckedYet, _): return "Not checked yet: shows once the speaker answers"
        }
    }
}

/// When the permissions guide opens by itself, and what it lists.
public enum PermissionsGuide {
    /// How often the open guide asks macOS about Accessibility again, so
    /// the tick appears soon after he switches it on. macOS sends no
    /// notification for it. The check is cheap, and stops when the
    /// window closes.
    public static let recheckInterval: Duration = .seconds(1)

    /// Open at launch, instead of the bare system prompt, when the volume
    /// keys can't work. Local Network is always "not checked yet" at
    /// launch, so it doesn't count here; the menu's red dot points to
    /// the guide once macOS blocks it.
    public static func showsAtLaunch(accessibility: PermissionStatus) -> Bool {
        accessibility != .granted
    }

    /// The rows, top to bottom.
    public static func rows(accessibility: PermissionStatus, localNetwork: PermissionStatus) -> [PermissionRow] {
        [PermissionRow(.accessibility, status: accessibility), PermissionRow(.localNetwork, status: localNetwork)]
    }
}
