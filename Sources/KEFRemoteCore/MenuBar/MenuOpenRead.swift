import Foundation

/// Whether opening the menu reads the speaker's source byte again.
///
/// The speaker changes by itself: AirPlay from the Mac switched it to
/// Wi-Fi while the menu still said Optical, until a volume key read it
/// (hand test round 5). So each open reads it, at most once, so Input ▸
/// and Turn speaker on/off show what the speaker is now:
///
/// ```
/// menu opened ─┬─ not connected ............ skip (a read would only time out)
///              ├─ an exchange in flight .... skip (the connection takes one at a time)
///              ├─ read under 3 s ago ....... skip (it's fresh)
///              └─ otherwise ................ read once
/// ```
///
/// Each open logs ``logLine`` under `menubar`.
public enum MenuOpenRead: Equatable, Sendable {
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

    public var logLine: String {
        switch self {
        case .read(let ago?):
            return "menu opened: reading the speaker's input (last read \(ago.components.seconds) s ago)"
        case .read(nil):
            return "menu opened: reading the speaker's input (not read yet)"
        case .skipNotConnected:
            return "menu opened: not reading the input, the speaker isn't connected"
        case .skipBusy:
            return "menu opened: not reading the input, a command is talking to the speaker"
        case .skipReadRecently(let ago):
            return "menu opened: input read \(ago.components.seconds) s ago, not reading it again"
        }
    }
}
