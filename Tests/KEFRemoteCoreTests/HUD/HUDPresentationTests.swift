import Testing
@testable import KEFRemoteCore

struct HUDPresentationTests {

    @Test func volumeShowsThePercentage() {
        #expect(HUDPresentation(.volume(level: 42)).label == "42%")
    }

    @Test func louderVolumeShowsMoreWaves() {
        #expect(HUDPresentation(.volume(level: 0)).symbolName == "speaker.fill")
        #expect(HUDPresentation(.volume(level: 1)).symbolName == "speaker.wave.1.fill")
        #expect(HUDPresentation(.volume(level: 32)).symbolName == "speaker.wave.1.fill")
        #expect(HUDPresentation(.volume(level: 33)).symbolName == "speaker.wave.2.fill")
        #expect(HUDPresentation(.volume(level: 65)).symbolName == "speaker.wave.2.fill")
        #expect(HUDPresentation(.volume(level: 66)).symbolName == "speaker.wave.3.fill")
        #expect(HUDPresentation(.volume(level: 100)).symbolName == "speaker.wave.3.fill")
    }

    @Test func mutedShowsACrossedOutSpeaker() {
        #expect(HUDPresentation(.muted).symbolName == "speaker.slash.fill")
        #expect(HUDPresentation(.muted).label == "Muted")
    }

    @Test func powerOnAndOffShareTheIconButNotTheLabel() {
        #expect(HUDPresentation(.powerOn).symbolName == "power")
        #expect(HUDPresentation(.powerOff).symbolName == "power")
        #expect(HUDPresentation(.powerOn).label == "Power On")
        #expect(HUDPresentation(.powerOff).label == "Power Off")
    }

    @Test func anErrorShowsItsMessageUnderAWarning() {
        let shown = HUDPresentation(.error("Command failed"))
        #expect(shown.symbolName == "exclamationmark.triangle.fill")
        #expect(shown.label == "Command failed")
    }

    @Test func wakingShowsRadioWaves() {
        #expect(HUDPresentation(.waking).symbolName == "antenna.radiowaves.left.and.right")
        #expect(HUDPresentation(.waking).label == "Waking...")
    }

    @Test func anInputShowsItsName() {
        #expect(HUDPresentation(.input(.optical)).label == "Optical")
        #expect(HUDPresentation(.input(.wifi)).label == "Wi-Fi")
        #expect(HUDPresentation(.input(.optical)).symbolName == "hifispeaker.fill")
    }

    /// The speaker reports Bluetooth as unpaired while nothing is paired.
    @Test func bluetoothShowsAsBluetoothPairedOrNot() {
        #expect(HUDPresentation(.input(.bluetoothPaired)).label == "Bluetooth")
        #expect(HUDPresentation(.input(.bluetoothUnpaired)).label == "Bluetooth")
    }

    // MARK: - A failed command

    /// Live test, 5 Oct: with the speaker unplugged the HUD said
    /// "Command failed". Say what's wrong instead.
    @Test func aCommandThatCannotReachTheSpeakerSaysSo() {
        for error in [KEFError.commandTimeout, .connectionFailed("timed out"), .connectionRefused, .notConnected] {
            #expect(HUDState.failure(error, otherwise: "Command failed") == .error("Can't reach the speaker"), "\(error)")
        }
    }

    @Test func aBadReplyKeepsTheCommandsOwnMessage() {
        #expect(HUDState.failure(KEFError.invalidResponse, otherwise: "Power failed") == .error("Power failed"))
    }

    // MARK: - After an input switch

    @Test func aSwitchThatTookShowsTheInputTheSpeakerIsOn() {
        #expect(HUDState.afterInputSwitch(.switched(.bluetoothUnpaired)) == .input(.bluetoothUnpaired))
        #expect(HUDPresentation(.afterInputSwitch(.switched(.bluetoothUnpaired))).label == "Bluetooth")
    }

    /// Not the input it asked for: the LSX stayed on Aux when asked for USB.
    @Test func aSwitchThatDidNotTakeSaysTheInputIsNotAvailable() {
        let state = HUDState.afterInputSwitch(.notTaken(asked: .usb, stayedOn: .aux))
        #expect(state == .error("USB not available"))
    }

    @Test func aSwitchToASpeakerThatIsOffSaysItIsOff() {
        #expect(HUDState.afterInputSwitch(.speakerOff) == .error("Speaker is off"))
    }

    @Test func anUnknownErrorKeepsTheCommandsOwnMessage() {
        struct Other: Error {}
        #expect(HUDState.failure(Other(), otherwise: "Command failed") == .error("Command failed"))
    }
    // MARK: - Power toggle

    @Test func aPowerToggleShowsWhichWayItWent() {
        #expect(HUDState.afterPowerToggle(.turnedOn) == .powerOn)
        #expect(HUDState.afterPowerToggle(.turnedOff) == .powerOff)
    }

    /// A repeat the guard ignored shows nothing: the toggle it repeated
    /// shows the HUD, so a burst doesn't flash it 175 more times.
    @Test func anIgnoredPowerToggleShowsNothing() {
        #expect(HUDState.afterPowerToggle(.ignored(.inFlight)) == nil)
    }

    // MARK: - Turn speaker on / off in the menu

    @Test func aPowerMenuClickShowsWhichWayItWent() {
        #expect(HUDState.afterPowerMenu(.done(.powerOn)) == .powerOn)
        #expect(HUDState.afterPowerMenu(.done(.powerOff)) == .powerOff)
    }

    /// Nothing changed, so nothing flashes up: the menu's label follows
    /// the byte the click read.
    @Test func aPowerMenuClickThatSentNothingShowsNothing() {
        #expect(HUDState.afterPowerMenu(.done(.alreadyOn)) == nil)
        #expect(HUDState.afterPowerMenu(.done(.alreadyOff)) == nil)
        #expect(HUDState.afterPowerMenu(.ignored(.tooSoon(sinceLast: .milliseconds(300)))) == nil)
    }

}
