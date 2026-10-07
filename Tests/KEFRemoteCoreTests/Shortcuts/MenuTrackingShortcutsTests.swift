import Testing
@testable import KEFRemoteCore

/// While any of the app's menus is open, the global shortcuts are off:
/// KeyboardShortcuts says so (NSMenuItem++.swift), and its menu mode
/// re-fired one key-up 176 times in the 6 Oct hand test.
struct MenuTrackingShortcutsTests {

    @Test func aMenuOpeningTurnsShortcutsOff() {
        var rule = MenuTrackingShortcuts()
        #expect(rule.menuBegan(shortcutsOn: true) == .disable)
        #expect(rule.disabledForMenu)
    }

    @Test func theMenuClosingTurnsThemBackOn() {
        var rule = MenuTrackingShortcuts()
        _ = rule.menuBegan(shortcutsOn: true)
        #expect(rule.menuEnded() == .enable)
        #expect(!rule.disabledForMenu)
    }

    /// Off the home network they are off already, and must stay off when
    /// the menu closes.
    @Test func offTheHomeNetworkAMenuChangesNothing() {
        var rule = MenuTrackingShortcuts()
        #expect(rule.menuBegan(shortcutsOn: false) == .leaveOff)
        #expect(rule.menuEnded() == .leave)
    }

    /// A second begin before the end (a menu opened from a menu) doesn't
    /// count twice: one end turns them back on.
    @Test func aSecondBeginBeforeTheEndChangesNothing() {
        var rule = MenuTrackingShortcuts()
        _ = rule.menuBegan(shortcutsOn: true)
        #expect(rule.menuBegan(shortcutsOn: true) == .leave)
        #expect(rule.menuEnded() == .enable)
    }

    /// An end with no begin it matches (the app started mid-menu) leaves
    /// the shortcuts as they are.
    @Test func anEndWithoutABeginChangesNothing() {
        var rule = MenuTrackingShortcuts()
        #expect(rule.menuEnded() == .leave)
    }

    @Test func eachChangeSaysWhyInTheLog() {
        #expect(MenuTrackingShortcuts.Change.disable.logLine == "shortcuts paused: a menu is open")
        #expect(MenuTrackingShortcuts.Change.enable.logLine == "shortcuts back on: the menu closed")
        #expect(MenuTrackingShortcuts.Change.leaveOff.logLine
            == "menu opened: shortcuts already off (off the home network)")
        #expect(MenuTrackingShortcuts.Change.leave.logLine == nil)
    }
}
