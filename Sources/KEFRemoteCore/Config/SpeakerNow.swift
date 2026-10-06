/// What the speaker is set to now, as Settings › Speaker shows it beside
/// each choice, so Don't change doesn't hide the speaker's own value
/// (hand test round 6: after swapping left and right in KEF's app, he
/// couldn't tell which way it was).
///
/// ```
/// Input on turn-on     [Don't change (now Optical)]
/// Standby              [Don't change (now 60 min)]
/// Swap left and right  [on]   Now: swapped
/// ```
///
/// All three come from the last source byte read or written; opening
/// Settings reads it again (``SourceByteRefresh``).
public struct SpeakerNow: Equatable, Sendable {
    /// The speaker's source byte, or nil when it isn't known now.
    private let source: SourceByte?
    private let isConnected: Bool

    /// - Parameters:
    ///   - speakerSource: The last source byte read or written, or nil
    ///     before the first read.
    ///   - isConnected: The speaker answered the last exchange. Once it
    ///     stops answering the byte may be stale (KEF's app can change
    ///     it), so nothing is claimed.
    public init(speakerSource: SourceByte?, isConnected: Bool) {
        self.source = isConnected ? speakerSource : nil
        self.isConnected = isConnected
    }

    /// The Standby picker's name for `choice`: Don't change says the
    /// speaker's time when it's known.
    public func label(for choice: StandbyChoice) -> String {
        Self.dontChange(choice.label, now: choice == .dontChange ? source?.standby.label : nil)
    }

    /// The Input on turn-on picker's name for `choice`: Don't change
    /// says the speaker's input when it's known.
    public func label(for choice: PowerOnInput) -> String {
        Self.dontChange(choice.label, now: choice == .dontChange ? source?.input.label : nil)
    }

    /// Under Swap left and right: which way the speaker is now. The
    /// switch alone can't say, as it's off while greyed out.
    public var swapCaption: String {
        guard isConnected else { return "Not connected" }
        guard let source else { return "Not read yet" }
        return source.isInversed ? "Now: swapped" : "Now: normal"
    }

    private static func dontChange(_ label: String, now: String?) -> String {
        now.map { "\(label) (now \($0))" } ?? label
    }
}
