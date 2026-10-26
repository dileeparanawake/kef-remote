import Foundation
import Testing
@testable import KEFRemoteCore

struct MenuLinkTests {

    @Test func madeByOpensHisSite() {
        #expect(MenuLink.madeBy.url?.absoluteString == "https://www.dileeparanawake.com")
        #expect(MenuLink.madeBy.title == "Made by Dileepa ↗")
    }

    @Test func supportHasATitleThatSaysItOpensMore() {
        #expect(MenuLink.support.title == "Buy me a coffee…")
    }

    @Test func aLinkWithAPageIsShown() {
        #expect(MenuLink.shown(supportURL: URL(string: "https://example.com/kef")) == [.support, .madeBy])
    }

    @Test func supportIsHiddenUntilItsPageExists() {
        #expect(MenuLink.shown(supportURL: nil) == [.madeBy])
    }

    @Test func supportOpensHisKoFiPage() {
        #expect(MenuLink.support.url?.absoluteString == "https://ko-fi.com/dileepabuilds")
        #expect(MenuLink.shown == [.support, .madeBy])
    }
}
