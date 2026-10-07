import Foundation

/// Whether opening the menu, or Settings, reads the speaker's source byte
/// again.
///
/// The speaker changes by itself: AirPlay from the Mac switched it to
/// Wi-Fi while the menu still said Optical, until a volume key read it
/// (hand test round 5). So each open reads it, at most once, so Input ▸
/// and Turn speaker on/off show what the speaker is now, and so do
/// Settings' "Don't change (now 60 min)" and "Now: swapped" (``SpeakerNow``):
///
/// ```
/// opened ──────┬─ not connected ............ skip (a read would only time out)
///              ├─ an exchange in flight .... skip (the connection takes one at a time)
///              ├─ read under 3 s ago ....... skip (it's fresh)
///              └─ otherwise ................ read once
/// ```
///
/// Each open logs ``logLine(on:)``: the menu under `menubar`, Settings
/// under `settings`.
public enum SourceByteRefresh: Equatable, Sendable {
    /// Read the source byte. `lastReadAgo` is nil before the first read.
    case read(lastReadAgo: Duration?)
    case skipNotConnected
    case skipBusy
    /// The byte was read (or written and acked) this long ago.
    case skipReadRecently(Duration)

    /// How long a source byte counts as fresh. Long enough that opening
    /// the menu twice in a row, or just after a key press that read it,
    /// sends nothing; short enough that a change by AirPlay or KEF's own
    /// remote shows the next time he looks.
    public static let freshFor: Duration = .seconds(3)

    /// - Parameters:
    ///   - isConnected: The speaker answered the last exchange.
    ///   - isExchangeInFlight: A command is waiting for the speaker's reply.
    ///   - sourceByteAge: Time since the source byte was last read, or
    ///     written and acked; nil before the first.
    public init(isConnected: Bool, isExchangeInFlight: Bool, sourceByteAge: Duration?) {
        if !isConnected {
            self = .skipNotConnected
        } else if isExchangeInFlight {
            self = .skipBusy
        } else if let age = sourceByteAge, age < Self.freshFor {
            self = .skipReadRecently(age)
        } else {
            self = .read(lastReadAgo: sourceByteAge)
        }
    }

    /// Whether to send the read.
    public var reads: Bool {
        if case .read = self { return true }
        return false
    }

    /// What opened, for the log line.
    public enum Opening: Sendable {
        /// The menu bar menu: it shows the input.
        case menu
        /// The settings window: it shows standby, input and swap.
        case settings

        var name: String {
            switch self {
            case .menu: "menu"
            case .settings: "Settings"
            }
        }

        /// What the read is for, as the line names it.
        var readsFor: String {
            switch self {
            case .menu: "input"
            case .settings: "source byte"
            }
        }
    }

    public func logLine(on opening: Opening) -> String {
        let (name, what) = (opening.name, opening.readsFor)
        switch self {
        case .read(let ago?):
            return "\(name) opened: reading the speaker's \(what) (last read \(ago.components.seconds) s ago)"
        case .read(nil):
            return "\(name) opened: reading the speaker's \(what) (not read yet)"
        case .skipNotConnected:
            return "\(name) opened: not reading the \(what), the speaker isn't connected"
        case .skipBusy:
            return "\(name) opened: not reading the \(what), a command is talking to the speaker"
        case .skipReadRecently(let ago):
            return "\(name) opened: \(what) read \(ago.components.seconds) s ago, not reading it again"
        }
    }
}
