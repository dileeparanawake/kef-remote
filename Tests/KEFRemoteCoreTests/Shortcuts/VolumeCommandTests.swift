import Testing
@testable import KEFRemoteCore

/// Which volume key a system-defined key code is (IOKit's NX_KEYTYPE_*).
struct VolumeCommandTests {

    @Test func volumeKeys() {
        #expect(VolumeCommand(mediaKeyCode: 0) == .up)
        #expect(VolumeCommand(mediaKeyCode: 1) == .down)
        #expect(VolumeCommand(mediaKeyCode: 7) == .mute)
    }

    /// Play/pause (16), next and previous (17 to 20) stay the Mac's: the
    /// speaker ignores them (hand test round 6).
    @Test func playbackKeysStayTheMacs() {
        for keyCode in 16...20 {
            #expect(VolumeCommand(mediaKeyCode: keyCode) == nil)
        }
    }

    /// Brightness (2, 3), eject (14) and the rest stay the Mac's.
    @Test func otherKeysAreNotOurs() {
        for keyCode in [2, 3, 14, 21, 99] {
            #expect(VolumeCommand(mediaKeyCode: keyCode) == nil)
        }
    }

    @Test func logNamesArePlain() {
        #expect(VolumeCommand.up.description == "volume up")
        #expect(VolumeCommand.down.description == "volume down")
        #expect(VolumeCommand.mute.description == "mute")
    }
}
