import Foundation

/// A search the app makes by itself that finds no KEF searches again a
/// couple of times, a few seconds apart, before the menu bar says no
/// speaker.
///
/// ```
/// search ─▶ found ─────────────────────────────▶ connect
///   │ no KEF
///   ├─ a click ─────────────────────────────────▶ noSpeaker
///   └─ by itself: wait 3 s, search again (twice) ▶ noSpeaker
/// ```
///
/// Hand test, 6 Oct: the search made the moment Local Network was allowed
/// heard 9 replies, all from the Hue bridge, and none from the speaker
/// (it was in standby). Find speaker 50 s later found it in under a
/// second. A speaker in standby can miss a multicast M-SEARCH, and both
/// of one search's go out within a second, so a later search catches it.
///
/// A click searches once: he's watching for the answer, and can click again.
public enum SearchAgain {
    /// Searches after the first one misses. Two more cover a speaker that
    /// is slow to wake its network, without leaving the menu bar on
    /// Searching for long (about 15 s in all).
    public static let times = 2
    /// Between searches: long enough for a speaker in standby to wake
    /// its network, short enough that the menu bar answers soon.
    public static let pause: Duration = .seconds(3)

    /// How many times a miss searches again, for what started the run.
    public static func times(after trigger: DiscoveryTrigger) -> Int {
        trigger.isClick ? 0 : times
    }
}
