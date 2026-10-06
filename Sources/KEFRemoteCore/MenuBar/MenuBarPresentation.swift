import Foundation

/// How a ``ConnectionStatus`` and the Accessibility permission look in
/// the menu bar: the icon, its dot, and the two lines at the top of the
/// menu.
///
/// ```
/// icon, no dot              icon with a red dot
/// Connected to LSX           Can't reach LSX: click Find speaker
/// 192.168.1.80               No answer at 192.168.1.80
///                            Find speaker
/// ```
///
/// The red dot marks a state that needs him. It is a shape as well as a
/// colour, so it reads without colour vision. A state with a dot puts
/// what's wrong and what to do on the menu's first line. A green dot
/// shows briefly on connecting (see ``ConnectedFlash``), and an orange
/// one pulses while it looks for the speaker (see ``SearchingPulse``).
///
/// With Accessibility off the volume keys can't work, so that needs him
/// too. Which problem gets the two lines while Accessibility is off:
///
/// ```
/// connection           first line                              dot
/// ───────────────────  ──────────────────────────────────────  ──────
/// noSpeaker            No speaker set: click Find speaker      red
/// notConnected         Can't reach LSX: click Find speaker     red
/// localNetworkBlocked  Can't reach LSX: allow Local Network…   red
/// searching            Not connected                           orange
/// connecting           Volume keys off: allow Accessibility    red
/// connected            Volume keys off: allow Accessibility    red
/// dormant              Volume keys off: allow Accessibility    red
/// ```
///
/// A connection that needs him keeps its lines, so the Find speaker item
/// under them still makes sense, and the Permissions… item says a
/// permission needs him (``PermissionsGuide/menuItemTitle(rows:)``). A
/// search he just started keeps its orange pulse; the red dot is back
/// once it ends. The other states sort themselves out, so Accessibility
/// takes the lines. The icon keeps the connection's shape: the dot is
/// what says he's needed.
public struct MenuBarPresentation: Equatable, Sendable {
    /// An SF Symbol name.
    public let symbolName: String
    /// Show a red dot on the icon: something needs him.
    public let needsAttention: Bool
    /// The dot to draw: red when it needs him, orange while it looks for
    /// the speaker, green while it has just connected, else none. Red
    /// always wins.
    public let dot: MenuBarDot
    /// True only when the speaker answered the last exchange.
    public let isConnected: Bool
    /// The menu's first line: connected, or what's wrong and what to do.
    public let title: String
    /// The menu's second line: where the speaker is, or more on what's wrong.
    public let detail: String
    /// Whether the menu shows "Find speaker". Hidden while discovery
    /// already runs, and off the home network, where it can't find anything.
    public let offersFindSpeaker: Bool

    /// What VoiceOver reads for the icon.
    public var accessibilityLabel: String { "KEF Remote: \(title). \(detail)" }

    /// The outline speaker: while checking, and under the red and orange
    /// dots. Plain, because the dot sits where a badge would be.
    static let plainSpeakerSymbol = "hifispeaker"
    static let notConnectedTitle = "Not connected"

    /// - Parameters:
    ///   - accessibility: Whether the volume keys may reach the speaker.
    ///     Only ``PermissionStatus/notGranted`` needs him.
    ///   - isFlashingConnected: Within ``ConnectedFlash/duration`` of
    ///     becoming connected.
    public init(
        status: ConnectionStatus,
        accessibility: PermissionStatus,
        speakerName: String?,
        ip: String?,
        isFlashingConnected: Bool = false
    ) {
        let name = speakerName ?? "the speaker"
        let address = ip ?? "no IP"

        isConnected = status == .connected

        switch status {
        case .dormant, .searching, .connected:
            offersFindSpeaker = false
        case .noSpeaker, .connecting, .notConnected, .localNetworkBlocked:
            offersFindSpeaker = true
        }

        // See the table above.
        let connectionNeedsHim: Bool
        let accessibilityTakesTheLines: Bool
        switch status {
        case .noSpeaker, .notConnected, .localNetworkBlocked:
            connectionNeedsHim = true
            accessibilityTakesTheLines = false
        case .searching:
            connectionNeedsHim = false
            accessibilityTakesTheLines = false
        case .connected, .connecting, .dormant:
            connectionNeedsHim = false
            accessibilityTakesTheLines = accessibility == .notGranted
        }
        needsAttention = connectionNeedsHim || accessibilityTakesTheLines

        if needsAttention {
            dot = .needsAttention
        } else if status == .searching {
            dot = .searching
        } else if isConnected && isFlashingConnected {
            dot = .justConnected
        } else {
            dot = .none
        }

        let lines: (title: String, detail: String)
        switch status {
        case .dormant:
            symbolName = "speaker.slash"
            lines = (Self.notConnectedTitle, "Paused: not on home network")
        case .searching:
            // The speaker stays (Round 3, 5 Oct): the pulsing dot says
            // it's looking, so the icon doesn't jump to a new shape.
            symbolName = Self.plainSpeakerSymbol
            lines = (Self.notConnectedTitle, "Looking for the speaker…")
        case .connecting:
            symbolName = Self.plainSpeakerSymbol
            lines = (Self.notConnectedTitle, "Checking \(name) at \(address)…")
        case .connected:
            symbolName = "hifispeaker.fill"
            lines = ("Connected to \(name)", address)
        case .noSpeaker:
            symbolName = Self.plainSpeakerSymbol
            lines = ("No speaker set: click Find speaker", "Or type its IP in Settings…")
        case .notConnected:
            symbolName = Self.plainSpeakerSymbol
            lines = ("Can't reach \(name): click Find speaker", "No answer at \(address)")
        case .localNetworkBlocked:
            symbolName = Self.plainSpeakerSymbol
            // Permissions… in this menu opens the pane (``PermissionsGuide``).
            lines = ("Can't reach \(name): allow Local Network in System Settings", "Click Permissions… to open the setting")
        }

        if accessibilityTakesTheLines {
            title = "Volume keys off: allow Accessibility"
            detail = "Click Permissions… to turn it on"
        } else {
            title = lines.title
            detail = lines.detail
        }
    }
}
