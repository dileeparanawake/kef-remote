import Testing
@testable import KEFRemoteCore

/// Which media key a system-defined key code is (IOKit's NX_KEYTYPE_*).
struct MediaKeyTests {

    @Test func volumeKeys() {
        #expect(MediaKey(keyCode: 0) == .volume(.up))
        #expect(MediaKey(keyCode: 1) == .volume(.down))
        #expect(MediaKey(keyCode: 7) == .volume(.mute))
    }

    @Test func playPause() {
        #expect(MediaKey(keyCode: 16) == .playback(.playPause))
    }

    /// Keyboards send one pair or the other for F9 and F7: NEXT and
    /// PREVIOUS (17, 18) or FAST and REWIND (19, 20). Both pairs skip.
    @Test func nextAndPreviousFromEitherPair() {
        #expect(MediaKey(keyCode: 17) == .playback(.next))
        #expect(MediaKey(keyCode: 19) == .playback(.next))
        #expect(MediaKey(keyCode: 18) == .playback(.previous))
        #expect(MediaKey(keyCode: 20) == .playback(.previous))
    }

    /// Brightness (2, 3), eject (14) and the rest stay the Mac's.
    @Test func otherKeysAreNotOurs() {
        for keyCode in [2, 3, 14, 21, 99] {
            #expect(MediaKey(keyCode: keyCode) == nil)
        }
    }

    @Test func logNamesArePlain() {
        #expect(MediaKey.volume(.up).description == "volume up")
        #expect(MediaKey.volume(.down).description == "volume down")
        #expect(MediaKey.volume(.mute).description == "mute")
        #expect(MediaKey.playback(.playPause).description == "play/pause")
        #expect(MediaKey.playback(.next).description == "next")
        #expect(MediaKey.playback(.previous).description == "previous")
    }
}
