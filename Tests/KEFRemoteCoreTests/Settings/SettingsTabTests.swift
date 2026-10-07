import Testing
@testable import KEFRemoteCore

/// Settings in three tabs, so the window fits a 13-inch MacBook (hand
/// test round 5: with the shortcut rows it was taller than the screen).
struct SettingsTabTests {

    @Test func theTabsRunSpeakerKeysAbout() {
        #expect(SettingsTab.allCases.map(\.title) == ["Speaker", "Keys", "About"])
    }

    @Test func settingsOpensOnSpeaker() {
        #expect(SettingsTab.first == .speaker)
    }

    @Test func eachTabHasItsOwnIcon() {
        let icons = SettingsTab.allCases.map(\.systemImage)
        #expect(Set(icons).count == icons.count)
        #expect(!icons.contains(""))
    }

    /// A 13-inch MacBook Air shows about 800 pt under the menu bar. The
    /// title bar and tab bar sit on top of the content, and the whole
    /// window has to stay under about 600 pt.
    @Test func aTabsContentStaysWellUnderASmallScreen() {
        #expect(SettingsTab.maxContentHeight <= 520)
    }
}

struct AppVersionTests {

    @Test func theAboutLineNamesTheVersionAndBuild() {
        let version = AppVersion(info: ["CFBundleShortVersionString": "0.3.0", "CFBundleVersion": "3"])
        #expect(version.short == "0.3.0")
        #expect(version.build == "3")
        #expect(version.aboutLine == "Version 0.3.0 (3)")
    }

    /// A missing Info.plist entry says so, rather than leaving a gap.
    @Test func aMissingEntryReadsUnknown() {
        let version = AppVersion(info: nil)
        #expect(version.short == "unknown")
        #expect(version.build == "unknown")
        #expect(version.aboutLine == "Version unknown (unknown)")
    }
}
