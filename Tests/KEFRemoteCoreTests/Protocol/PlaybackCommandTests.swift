import Foundation
import Testing
@testable import KEFRemoteCore

/// Play/pause, next and previous: kefctl's `53 31 81 81 / 82 / 83`.
struct PlaybackCommandTests {

    @Test func playPauseNextAndPreviousAreKefctlsBytes() {
        #expect(KEFCommand.setPlayback(.playPause) == Data([0x53, 0x31, 0x81, 0x81]))
        #expect(KEFCommand.setPlayback(.next) == Data([0x53, 0x31, 0x81, 0x82]))
        #expect(KEFCommand.setPlayback(.previous) == Data([0x53, 0x31, 0x81, 0x83]))
    }

    /// The speaker streams Wi-Fi and Bluetooth itself, so it can play,
    /// pause and skip them. Optical, Aux and USB come from another device.
    @Test func onlyWiFiAndBluetoothHavePlayback() {
        #expect(InputSource.wifi.hasPlayback)
        #expect(InputSource.bluetoothPaired.hasPlayback)
        #expect(InputSource.bluetoothUnpaired.hasPlayback)
        #expect(!InputSource.optical.hasPlayback)
        #expect(!InputSource.aux.hasPlayback)
        #expect(!InputSource.usb.hasPlayback)
    }

    @Test func logNamesArePlain() {
        #expect(PlaybackCommand.playPause.name == "play/pause")
        #expect(PlaybackCommand.next.name == "next")
        #expect(PlaybackCommand.previous.name == "previous")
    }
}
