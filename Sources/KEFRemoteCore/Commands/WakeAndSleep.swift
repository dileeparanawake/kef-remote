import Foundation

extension SpeakerController {
    /// The Mac woke: set the wake standby time, then turn the speaker on
    /// if `powerOn`. One step after the other: each reads the source byte
    /// and writes it back, so two at once could undo each other's write
    /// (and turn the speaker back off).
    public func macWoke(_ settings: SpeakerSettings, powerOn: Bool) async throws {
        log(.info, "wake: standby\(powerOn ? ", then power on" : " only")")
        try await applyStandby(settings, for: .wake)
        if powerOn {
            try await self.powerOn(applying: settings)
        }
    }

    /// The Mac has slept for the power-off delay: ask for 20 min standby,
    /// then turn the speaker off if `powerOff`, in that order for the
    /// same reason as ``macWoke(_:powerOn:)``. Power-off still switches
    /// 20 to 60 min first.
    public func macSlept(_ settings: SpeakerSettings, powerOff: Bool) async throws {
        log(.info, "sleep: standby\(powerOff ? ", then power off" : " only")")
        try await applyStandby(settings, for: .sleep)
        if powerOff {
            try await self.powerOff()
        }
    }
}
