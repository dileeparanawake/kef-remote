import Foundation
import Testing
@testable import KEFRemoteCore

struct MenuLinkTests {

    @Test func madeByOpensThePortfolio() {
        #expect(MenuLink.madeBy.url?.absoluteString == "https://dileeparanawake.github.io/")
        #expect(MenuLink.madeBy.title == "Made by Dileepa ↗")
    }

    @Test func supportHasATitleThatSaysItOpensMore() {
        #expect(MenuLink.support.title == "Support KEF Remote…")
    }

    @Test func aLinkWithAPageIsShown() {
        #expect(MenuLink.shown(supportURL: URL(string: "https://example.com/kef")) == [.support, .madeBy])
    }

    @Test func supportIsHiddenUntilItsPageExists() {
        #expect(MenuLink.shown(supportURL: nil) == [.madeBy])
    }

    @Test func todaySupportHasNoPage() {
        // Dileepa hasn't made the Gumroad page yet (6 Oct 2026).
        #expect(MenuLink.support.url == nil)
        #expect(MenuLink.shown == [.madeBy])
    }
}
