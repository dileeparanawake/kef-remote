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

    /// How often the app asks about Accessibility while the guide is
    /// closed, so the menu bar's red dot comes or goes within a few
    /// seconds of a change in System Settings. Slower than the open
    /// guide: nobody is watching for a tick.
    public static let menuBarRecheckInterval: Duration = .seconds(3)

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

    /// The Permissions… item in the menu, so he sees at a glance whether
    /// he's done. Words and a tick, so it reads without colour.
    ///
    /// ```
    /// Permissions… ✓              every permission allowed
    /// Permissions… (1 needs you)  one not allowed
    /// Permissions…                none missing, Local Network not checked yet
    /// ```
    public static func menuItemTitle(rows: [PermissionRow]) -> String {
        let needingHim = rows.filter(\.needsAttention).count
        if needingHim == 1 { return "Permissions… (1 needs you)" }
        if needingHim > 1 { return "Permissions… (\(needingHim) need you)" }
        if rows.allSatisfy({ $0.status == .granted }) { return "Permissions… ✓" }
        return "Permissions…"
    }
}
