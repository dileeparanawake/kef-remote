import Foundation

/// Keeps a volume press from carrying a mute the speaker only shows for
/// a moment as it powers on.
///
/// In the second real check (6 Oct 2026) the LSX read 45% muted right as
/// power came on, though kefctl, polling every second, saw 45% unmuted all
/// through. Volume up and down keep the mute they read, so a press in that
/// moment wrote a muted volume and the speaker stayed muted.
///
/// The rule: for ``window`` after the app turns the speaker on, or after
/// a read shows it on when the last read showed it off, a press that reads
/// muted waits ``readAgainAfter`` and reads again, then goes by the second
/// read. It never unmutes by itself: a speaker muted on purpose still
/// reads muted the second time, so the press keeps the mute. In that
/// window a muted press only costs a second.
public struct PowerOnMuteGuard: Equatable, Sendable {
    /// How long after power on a muted read is read again. Power on took
    /// 5 s in the real check, and the muted moment comes as it lands; the
    /// check gives power on up to 20 s (``SpeakerCheck/powerChangeLimit``).
    public static let window: Duration = .seconds(20)
    /// How long to wait before reading again. Longer than the muted moment,
    /// which polling every second never caught.
    public static let readAgainAfter: Duration = .seconds(1)

    /// What the last source byte read said about power; nil before one.
    private var lastReadPoweredOn: Bool?
    /// When power came on, as far as the app knows.
    private var poweredOnAt: Duration?

    public init() {}

    /// The app wrote power on to a speaker that read off.
    public mutating func notePowerOnWrite(at now: Duration) {
        poweredOnAt = now
    }

    /// A source byte was read. On, when the last read was off, means power
    /// just came on (KEF's remote, say, or the app's own power on landing).
    public mutating func noteRead(_ source: SourceByte, at now: Duration) {
        if source.isPoweredOn, lastReadPoweredOn == false {
            poweredOnAt = now
        }
        lastReadPoweredOn = source.isPoweredOn
    }

    /// Whether a press that read `volume` at `now` should read it again.
    public func shouldReadAgain(_ volume: VolumeState, at now: Duration) -> Bool {
        guard volume.isMuted, let poweredOnAt else { return false }
        return now - poweredOnAt < Self.window
    }

    /// How long ago power came on, for the log; nil if never seen.
    public func sincePowerOn(at now: Duration) -> Duration? {
        poweredOnAt.map { now - $0 }
    }
}
