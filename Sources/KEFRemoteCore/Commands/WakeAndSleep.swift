import Foundation

extension SpeakerController {
    /// The Mac woke: set the wake standby time, then turn the speaker on
    /// if `powerOn`. One step after the other, in one turn of the
    /// ``SpeakerExchangeQueue``: each reads the source byte and writes it
    /// back, so another command between them could undo a write (and turn
    /// the speaker back off).
    public func macWoke(_ settings: SpeakerSettings, powerOn: Bool) async throws {
        try await queue.run {
            log(.info, "wake: standby\(powerOn ? ", then power on" : " only")")
            try await writeStandby(settings, for: .wake)
            if powerOn {
                try await turnOn(applying: settings)
            }
        }
    }

    /// The Mac has slept for the power-off delay: ask for 20 min standby,
    /// then turn the speaker off if `powerOff`, in one turn for the same
    /// reason as ``macWoke(_:powerOn:)``. Power-off still switches 20 to
    /// 60 min first.
    public func macSlept(_ settings: SpeakerSettings, powerOff: Bool) async throws {
        try await queue.run {
            log(.info, "sleep: standby\(powerOff ? ", then power off" : " only")")
            try await writeStandby(settings, for: .sleep)
            if powerOff {
                try await turnOff()
            }
        }
    }
}
