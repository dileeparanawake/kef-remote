import Foundation
import Testing
@testable import KEFRemoteCore

/// One row of the permissions guide: what it's for, a tick when granted,
/// and where in System Settings to allow it.
struct PermissionRowTests {

    // MARK: - What each permission is for

    @Test func accessibilityIsForTheVolumeKeys() {
        let row = PermissionRow(.accessibility, status: .notGranted)

        #expect(row.title == "Accessibility")
        #expect(row.purpose == "So the volume keys reach the speaker.")
        #expect(row.settingsPath == "Privacy & Security > Accessibility")
    }

    @Test func localNetworkIsForFindingTheSpeaker() {
        let row = PermissionRow(.localNetwork, status: .notCheckedYet)

        #expect(row.title == "Local Network")
        #expect(row.purpose == "So the app can find the speaker.")
        #expect(row.settingsPath == "Privacy & Security > Local Network")
    }

    // MARK: - The tick, and the words beside it

    @Test func aGrantedPermissionShowsATick() {
        for permission in Permission.allCases {
            let row = PermissionRow(permission, status: .granted)
            #expect(row.statusSymbol == "checkmark.circle.fill", "\(permission)")
            #expect(row.statusText == "Allowed", "\(permission)")
            #expect(!row.needsAttention, "\(permission)")
        }
    }

    @Test func missingAccessibilitySaysNotAllowedYet() {
        let row = PermissionRow(.accessibility, status: .notGranted)

        #expect(row.statusSymbol == "xmark.circle.fill")
        #expect(row.statusText == "Not allowed yet")
        #expect(row.needsAttention)
    }

    @Test func blockedLocalNetworkSaysBlocked() {
        let row = PermissionRow(.localNetwork, status: .notGranted)

        #expect(row.statusSymbol == "xmark.circle.fill")
        #expect(row.statusText == "Blocked: the app can't reach the speaker")
        #expect(row.needsAttention)
    }

    /// Local Network has no API: until the speaker is asked, the app
    /// doesn't know, so it says so rather than guess.
    @Test func uncheckedLocalNetworkSaysNotCheckedYet() {
        let row = PermissionRow(.localNetwork, status: .notCheckedYet)

        #expect(row.statusSymbol == "questionmark.circle")
        #expect(row.statusText == "Not checked yet: shows once the speaker answers")
        #expect(!row.needsAttention)
    }

    // MARK: - System Settings panes

    /// The legacy pane ID still opens Privacy & Security on macOS 14, 15
    /// and 26+: the Settings extension declares it as its
    /// `legacyBundleIdentifier`.
    @Test func accessibilityOpensPrivacyAccessibility() {
        #expect(Permission.accessibility.settingsURL.absoluteString
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @Test func localNetworkOpensPrivacyLocalNetwork() {
        #expect(Permission.localNetwork.settingsURL.absoluteString
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
    }

    // MARK: - When the guide opens by itself

    @Test func theGuideShowsAtLaunchWhenAccessibilityIsMissing() {
        #expect(PermissionsGuide.showsAtLaunch(accessibility: .notGranted))
    }

    @Test func theGuideStaysClosedAtLaunchWhenAccessibilityIsAllowed() {
        #expect(!PermissionsGuide.showsAtLaunch(accessibility: .granted))
    }

    @Test func theGuideRowsAreAccessibilityThenLocalNetwork() {
        let rows = PermissionsGuide.rows(accessibility: .granted, localNetwork: .notCheckedYet)

        #expect(rows.map(\.permission) == [.accessibility, .localNetwork])
        #expect(rows.map(\.status) == [.granted, .notCheckedYet])
    }

    // MARK: - The Permissions… item in the menu

    /// Hand test, 6 Oct: he wants to see at a glance, in the menu,
    /// whether the permissions are fine.
    @Test func whenBothAreAllowedTheMenuItemShowsATick() {
        let rows = PermissionsGuide.rows(accessibility: .granted, localNetwork: .granted)

        #expect(PermissionsGuide.menuItemTitle(rows: rows) == "Permissions… ✓")
    }

    @Test func whenOneIsMissingTheMenuItemSaysOneNeedsHim() {
        let rows = PermissionsGuide.rows(accessibility: .notGranted, localNetwork: .granted)

        #expect(PermissionsGuide.menuItemTitle(rows: rows) == "Permissions… (1 needs you)")
    }

    @Test func whenBothAreMissingTheMenuItemSaysTwoNeedHim() {
        let rows = PermissionsGuide.rows(accessibility: .notGranted, localNetwork: .notGranted)

        #expect(PermissionsGuide.menuItemTitle(rows: rows) == "Permissions… (2 need you)")
    }

    /// Local Network isn't known until the speaker is asked, so there is
    /// no tick yet, and nothing to ask of him either.
    @Test func whileLocalNetworkIsUncheckedTheMenuItemIsPlain() {
        let rows = PermissionsGuide.rows(accessibility: .granted, localNetwork: .notCheckedYet)

        #expect(PermissionsGuide.menuItemTitle(rows: rows) == "Permissions…")
    }

    @Test func missingAccessibilityCountsEvenWhileLocalNetworkIsUnchecked() {
        let rows = PermissionsGuide.rows(accessibility: .notGranted, localNetwork: .notCheckedYet)

        #expect(PermissionsGuide.menuItemTitle(rows: rows) == "Permissions… (1 needs you)")
    }

    /// The open guide asks every second; the slower check keeps the menu
    /// bar's red dot true while the guide is closed.
    @Test func theMenuBarChecksAccessibilityLessOftenThanTheOpenGuide() {
        #expect(PermissionsGuide.menuBarRecheckInterval > PermissionsGuide.recheckInterval)
    }
}
