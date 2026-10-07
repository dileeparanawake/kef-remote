import Foundation
import Testing
@testable import KEFRemoteCore

struct PrivacyNoticeTests {

    @Test func opensTheNoticeOnGitHub() {
        #expect(PrivacyNotice.url.absoluteString == "https://github.com/dileeparanawake/kef-remote/blob/main/PRIVACY.md")
    }

    @Test func settingsFooterSaysWhatItCollects() {
        #expect(PrivacyNotice.settingsTitle == "Privacy: KEF Remote collects nothing")
    }

    @Test func setupLinkIsOneQuietWord() {
        #expect(PrivacyNotice.setupTitle == "Privacy")
    }

    @Test func theMenuLeavesItOut() {
        // The menu is long enough: Settings and setup carry it instead.
        #expect(MenuLink.shown.allSatisfy { $0.url != PrivacyNotice.url })
    }
}
