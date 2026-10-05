import Testing
@testable import KEFRemoteCore

struct ShortcutActionTests {

    /// The storage names key each user's saved shortcut in UserDefaults
    /// (`KeyboardShortcuts_<name>`). Renaming one silently drops what the
    /// user recorded, so they are pinned here.
    @Test func storageNamesAreStable() {
        #expect(ShortcutAction.allCases.map(\.storageName)
            == ["powerToggle", "volumeUp", "volumeDown", "mute", "quit"])
    }

    @Test func storageNamesAreUnique() {
        let names = ShortcutAction.allCases.map(\.storageName)
        #expect(Set(names).count == names.count)
    }

    /// The old separate on and off shortcuts must not come back under the
    /// toggle's name: a stale ⇧⌘P "powerOff" would otherwise fire it.
    @Test func powerIsOneToggleNotOnAndOff() {
        let names = ShortcutAction.allCases.map(\.storageName)
        #expect(!names.contains("powerOn"))
        #expect(!names.contains("powerOff"))
    }

    @Test func everyActionHasASettingsLabel() {
        for action in ShortcutAction.allCases {
            #expect(!action.label.isEmpty)
        }
        #expect(ShortcutAction.powerToggle.label == "Power on/off")
    }

    // MARK: - No shortcut does two things

    /// Live test, 5 Oct: ⇧⌘O was both Power on/off and Volume down, so
    /// one press did both.
    @Test func aComboAnotherActionUsesIsAConflict() {
        let saved: [ShortcutAction: String] = [.powerToggle: "⇧⌘O", .quit: "⇧⌘Q"]
        #expect(ShortcutAction.volumeDown.conflict(with: "⇧⌘O", in: { saved[$0] }) == .powerToggle)
    }

    @Test func aFreeComboHasNoConflict() {
        let saved: [ShortcutAction: String] = [.powerToggle: "⇧⌘O"]
        #expect(ShortcutAction.volumeDown.conflict(with: "⌃⌥↓", in: { saved[$0] }) == nil)
    }

    /// Recording the same combo again on its own action is fine.
    @Test func anActionNeverConflictsWithItself() {
        let saved: [ShortcutAction: String] = [.powerToggle: "⇧⌘O"]
        #expect(ShortcutAction.powerToggle.conflict(with: "⇧⌘O", in: { saved[$0] }) == nil)
    }

    @Test func theRefusalNamesTheActionThatHasIt() {
        #expect(ShortcutAction.powerToggle.alreadyUsedMessage == "Already used for Power on/off")
    }
}
