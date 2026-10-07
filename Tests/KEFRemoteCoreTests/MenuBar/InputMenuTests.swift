import Testing
@testable import KEFRemoteCore

/// The Input ▸ submenu: which inputs it lists, in what order, which one
/// is ticked, and when it can be used.
struct InputMenuTests {
    /// The speaker on, on `input`.
    private func on(_ input: InputSource) -> SourceByte {
        SourceByte(isPoweredOn: true, isInversed: false, standby: .sixtyMinutes, input: input)
    }

    @Test func itListsTheInputsInSettingsOrder() {
        let menu = InputMenu(speakerSource: on(.optical), isConnected: true, inputs: SpeakerModel.other.inputs)
        #expect(menu.items.map(\.title) == ["Optical", "Wi-Fi", "Bluetooth", "Aux", "USB"])
    }

    /// The LSX has no USB input.
    @Test func onAnLSXItLeavesOutUSB() {
        let menu = InputMenu(speakerSource: on(.optical), isConnected: true, inputs: SpeakerModel.lsx.inputs)
        #expect(menu.items.map(\.title) == ["Optical", "Wi-Fi", "Bluetooth", "Aux"])
    }

    @Test func eachItemSwitchesToTheInputSettingsWould() {
        let menu = InputMenu(speakerSource: on(.optical), isConnected: true, inputs: SpeakerModel.other.inputs)
        #expect(menu.items.map(\.input) == PowerOnInput.allCases.compactMap(\.input))
        #expect(menu.items.map(\.input) == [.optical, .wifi, .bluetoothPaired, .aux, .usb])
    }

    @Test func theSpeakersInputIsTicked() {
        let menu = InputMenu(speakerSource: on(.wifi), isConnected: true, inputs: SpeakerModel.other.inputs)
        #expect(menu.items.filter(\.isTicked).map(\.title) == ["Wi-Fi"])
    }

    /// The speaker reports Bluetooth as unpaired while nothing is paired.
    @Test func bluetoothWithNothingPairedTicksBluetooth() {
        let menu = InputMenu(speakerSource: on(.bluetoothUnpaired), isConnected: true, inputs: SpeakerModel.other.inputs)
        #expect(menu.items.filter(\.isTicked).map(\.title) == ["Bluetooth"])
    }

    @Test func itCanBeUsedWhileConnected() {
        #expect(InputMenu(speakerSource: on(.optical), isConnected: true, inputs: SpeakerModel.other.inputs).isEnabled)
    }

    /// The last input read may be stale once the speaker stops answering.
    @Test func whenNotConnectedItIsGreyedOutWithNoTick() {
        let menu = InputMenu(speakerSource: on(.optical), isConnected: false, inputs: SpeakerModel.other.inputs)
        #expect(!menu.isEnabled)
        #expect(menu.items.allSatisfy { !$0.isTicked })
        #expect(menu.items.count == 5)
    }

    @Test func beforeTheFirstReadNothingIsTicked() {
        let menu = InputMenu(speakerSource: nil, isConnected: true, inputs: SpeakerModel.other.inputs)
        #expect(menu.isEnabled)
        #expect(menu.items.allSatisfy { !$0.isTicked })
    }

    /// KEF's remote can turn it on unseen, so a stale "off" mustn't grey
    /// it out; the switch itself checks.
    @Test func whileTheLastReadSaidOffItStaysEnabledAndKeepsItsTick() {
        let menu = InputMenu(
            speakerSource: on(.wifi).with(isPoweredOn: false), isConnected: true, inputs: SpeakerModel.other.inputs
        )
        #expect(menu.isEnabled)
        #expect(menu.items.filter(\.isTicked).map(\.title) == ["Wi-Fi"])
    }

    @Test func theSubmenuIsCalledInput() {
        #expect(InputMenu.title == "Input")
    }
}
