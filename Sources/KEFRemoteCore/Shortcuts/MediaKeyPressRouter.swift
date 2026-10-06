import Foundation

/// Sends both halves of a media key press the same way: to the speaker,
/// or to the Mac. The key-down decides, by whether the modifier is held.
///
/// In the hand test of 6 Oct 2026, Control + play/pause showed the HUD
/// and also opened Apple Music. The interceptor decided each half on its
/// own, so a key-down that reached the Mac before Control did (the Mac
/// starts its player on the key-down) and a key-up with Control held
/// (sent to the speaker) did both. Now a key-up follows its key-down.
public struct MediaKeyPressRouter: Sendable {
    public enum Route: Equatable, Sendable {
        /// Pass the event on: the Mac handles the key.
        case toMac
        /// Take the event from the Mac; nothing to send yet.
        case keep
        /// Take the event from the Mac and send the key to the speaker:
        /// once per press, on key-up, so a held key sends once.
        case keepAndSend
    }

    /// Key codes whose key-down was kept, or went to the Mac, and whose
    /// key-up hasn't come yet.
    private var keptKeyDowns: Set<Int> = []
    private var keyDownsToMac: Set<Int> = []

    public init() {}

    /// Where one half of a press goes. `keyCode` is the NX_KEYTYPE_* code.
    public mutating func route(keyCode: Int, isKeyUp: Bool, modifierHeld: Bool) -> Route {
        guard isKeyUp else {
            if modifierHeld {
                keptKeyDowns.insert(keyCode)
                keyDownsToMac.remove(keyCode)
                return .keep
            }
            keyDownsToMac.insert(keyCode)
            keptKeyDowns.remove(keyCode)
            return .toMac
        }
        if keptKeyDowns.remove(keyCode) != nil { return .keepAndSend }
        if keyDownsToMac.remove(keyCode) != nil { return .toMac }
        // No key-down seen (the tap started mid-press): go by the modifier.
        return modifierHeld ? .keepAndSend : .toMac
    }
}

extension MediaKeyPressRouter.Route: CustomStringConvertible {
    /// The route in log lines.
    public var description: String {
        switch self {
        case .toMac: "to the Mac"
        case .keep: "kept"
        case .keepAndSend: "kept, sent to the speaker"
        }
    }
}
