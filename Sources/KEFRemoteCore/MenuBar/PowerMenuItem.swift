import Foundation

/// Turn speaker on / Turn speaker off in the menu, just above Input ▸.
///
/// ```
/// Connected to LSX
/// 192.168.1.80
/// ─────────────
/// Turn speaker off        the last read said on
/// Input: Optical  ▸
/// ```
///
/// The words come from the last source byte, read again as the menu
/// opens (``MenuOpenRead``). A click flips whatever the speaker is
/// now, as the power shortcut does, so the input and standby defaults
/// apply when it turns on.
public struct PowerMenuItem: Equatable, Sendable {
    /// "Turn speaker off", "Turn speaker on", or "Turn speaker on/off"
    /// while the app doesn't know (before the first read, or not connected).
    public let title: String
    /// Greyed out while the speaker isn't connected: a click couldn't reach it.
    public let isEnabled: Bool

    /// - Parameters:
    ///   - speakerSource: The last source byte read or written, or nil
    ///     before the first read.
    ///   - isConnected: The speaker answered the last exchange.
    public init(speakerSource: SourceByte?, isConnected: Bool) {
        isEnabled = isConnected
        // Not connected, the last byte may be old: KEF's remote can turn
        // the speaker on or off without the app seeing it.
        switch isConnected ? speakerSource?.isPoweredOn : nil {
        case true?: title = "Turn speaker off"
        case false?: title = "Turn speaker on"
        case nil: title = "Turn speaker on/off"
        }
    }
}
