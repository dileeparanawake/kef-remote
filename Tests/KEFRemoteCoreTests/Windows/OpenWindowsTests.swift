import Testing
@testable import KEFRemoteCore

/// The Dock icon shows while any of the app's windows is open, so a
/// window behind another app's can be found again like any other.
struct OpenWindowsTests {

    @Test func theFirstWindowOpenedShowsTheDockIcon() {
        var windows = OpenWindows()
        #expect(windows.opened("setup") == .show)
        #expect(windows.needsDockIcon)
    }

    @Test func aSecondWindowChangesNothing() {
        var windows = OpenWindows()
        _ = windows.opened("setup")
        #expect(windows.opened("settings") == nil)
    }

    @Test func showingAnOpenWindowAgainChangesNothing() {
        var windows = OpenWindows()
        _ = windows.opened("setup")
        #expect(windows.opened("setup") == nil)
    }

    /// Hiding the Dock icon makes the app give up the front, which would
    /// drop the window still open behind other apps' windows.
    @Test func closingOneOfTwoKeepsTheDockIcon() {
        var windows = OpenWindows()
        _ = windows.opened("setup")
        _ = windows.opened("settings")
        #expect(windows.closed("settings") == nil)
        #expect(windows.needsDockIcon)
    }

    @Test func closingTheLastHidesTheDockIcon() {
        var windows = OpenWindows()
        _ = windows.opened("setup")
        #expect(windows.closed("setup") == .hide)
        #expect(!windows.needsDockIcon)
    }

    @Test func closingAWindowThatWasntOpenChangesNothing() {
        var windows = OpenWindows()
        #expect(windows.closed("settings") == nil)
    }
}
