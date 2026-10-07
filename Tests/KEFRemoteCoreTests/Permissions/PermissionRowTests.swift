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
    }

    @Test func localNetworkIsForFindingTheSpeaker() {
        let row = PermissionRow(.localNetwork, status: .notCheckedYet)

        #expect(row.title == "Local Network")
        #expect(row.purpose == "So the app can find the speaker.")
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

    /// Hand test, 6 Oct (macOS 27): the legacy pane ID,
    /// `com.apple.preference.security`, opened only the top of Privacy &
    /// Security. The pane's own extension ID is used on every macOS.
    @Test func accessibilityOpensTheAccessibilityRowByTheExtensionsID() {
        #expect(Permission.accessibility.settingsURL.absoluteString
            == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
    }

    /// The pane lists no Local Network anchor, so the link opens Privacy
    /// & Security and the hint says where to click next.
    @Test func localNetworkOpensPrivacyAndSecurityWithNoAnchor() {
        #expect(Permission.localNetwork.settingsURL.absoluteString
            == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
    }

    @Test func localNetworksHintSaysWhatToClickNext() {
        for major in [14, 15, 26, 27] {
            #expect(Permission.localNetwork.settingsHint(onMacOS: major)
                == "In Privacy & Security, click Local Network, then turn on KEF Remote", "macOS \(major)")
        }
    }

    @Test func accessibilitysHintNamesTheRowUpToMacOS26() {
        for major in [14, 15, 26] {
            #expect(Permission.accessibility.settingsHint(onMacOS: major)
                == "Privacy & Security > Accessibility", "macOS \(major)")
        }
    }

    /// macOS 27 renamed the row (the pane's `ACCESSIBILITY` string, read
    /// on his Mac on 6 Oct 2026), so the hint names what he'll see.
    @Test func accessibilitysHintNamesTheRenamedRowFromMacOS27() {
        for major in [27, 28] {
            #expect(Permission.accessibility.settingsHint(onMacOS: major)
                == "Privacy & Security > Device Control and Data Access", "macOS \(major)")
        }
    }

    @Test func theRowShowsThisMacsHint() {
        for permission in Permission.allCases {
            #expect(PermissionRow(permission, status: .notGranted).settingsHint == permission.settingsHint)
        }
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
