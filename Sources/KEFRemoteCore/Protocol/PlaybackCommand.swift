import Foundation

/// Play/pause, next and previous: the value written to the playback
/// register (0x31). The speaker passes them to what it is streaming.
/// Nothing reads them back, so only the ack says one arrived.
///
/// Reference: Perl `kefctl` `--play`, `--next`, `--previous`.
public enum PlaybackCommand: UInt8, CaseIterable, Sendable {
    /// Plays if paused, pauses if playing: one command for both.
    case playPause = 0x81
    case next = 0x82
    case previous = 0x83

    /// The name in log lines: "play/pause", "next", "previous".
    public var name: String {
        switch self {
        case .playPause: "play/pause"
        case .next: "next"
        case .previous: "previous"
        }
    }
}

extension InputSource {
    /// Whether the speaker can play, pause and skip on this input. It
    /// streams Wi-Fi and Bluetooth itself; Optical, Aux and USB come from
    /// another device, so there is nothing for it to control.
    public var hasPlayback: Bool {
        switch self {
        case .wifi, .bluetoothPaired, .bluetoothUnpaired: true
        case .optical, .aux, .usb: false
        }
    }
}
