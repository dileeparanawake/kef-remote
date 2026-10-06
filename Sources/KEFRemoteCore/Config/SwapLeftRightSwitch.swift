import Foundation

/// How the Swap left and right switch in Settings > Speaker
/// looks. Unlike the other choices there, it is the speaker's own
/// setting, applied when clicked and never saved in config.json: the
/// speaker keeps it.
///
/// ```
/// Swap left and right      [on]     the speaker's bit 6, as last read
/// Not changed: can't reach the speaker   only after a failed write
/// ```
public struct SwapLeftRightSwitch: Equatable, Sendable {
    public let isOn: Bool
    public let isEnabled: Bool

    public static let title = "Swap left and right"

    /// Under the row in Settings: written when clicked, kept by the speaker.
    public static let settingsCaption = "Now. The speaker remembers it."

    /// - Parameters:
    ///   - speakerSource: The speaker's last source byte read or written,
    ///     or nil before the first read.
    ///   - isConnected: The speaker answered the last exchange.
    ///   - requested: The state he just clicked, while the write is on
    ///     its way. Nil once it's done, so a failed write puts the switch
    ///     back to the speaker's state.
    public init(speakerSource: SourceByte?, isConnected: Bool, requested: Bool?) {
        // Once the speaker stops answering, the last byte may be stale
        // (KEF's own app can swap it too), so show off, greyed out.
        let known = isConnected ? speakerSource?.isInversed : nil
        isOn = requested ?? known ?? false
        // One write at a time, so two clicks can't race each other.
        isEnabled = known != nil && requested == nil
    }

    /// The note under the switch after a write failed.
    public static func failureNote(_ error: Error) -> String {
        let isUnreachable = (error as? KEFError)?.isConnectionFailure ?? false
        return isUnreachable ? "Not changed: can't reach the speaker" : "Not changed: the speaker didn't take it"
    }
}
