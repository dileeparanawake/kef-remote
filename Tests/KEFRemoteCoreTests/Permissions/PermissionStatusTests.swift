import Testing
@testable import KEFRemoteCore

/// What the permissions guide knows about each permission, and when it
/// changes. Accessibility has an API; Local Network is only seen through
/// the speaker answering, or macOS blocking it.
struct PermissionStatusTests {

    // MARK: - Accessibility

    @Test func aTrustedProcessHasAccessibility() {
        #expect(PermissionStatus(accessibilityTrusted: true) == .granted)
    }

    @Test func anUntrustedProcessDoesNotHaveAccessibility() {
        #expect(PermissionStatus(accessibilityTrusted: false) == .notGranted)
    }

    // MARK: - Local Network: read from the connection

    @Test func localNetworkIsNotCheckedUntilTheSpeakerIsAsked() {
        for status in [ConnectionStatus.dormant, .noSpeaker, .searching, .connecting] {
            #expect(PermissionStatus.notCheckedYet.localNetwork(after: status) == .notCheckedYet, "\(status)")
        }
    }

    @Test func theSpeakerAnsweringMeansLocalNetworkIsAllowed() {
        #expect(PermissionStatus.notCheckedYet.localNetwork(after: .connected) == .granted)
        #expect(PermissionStatus.notGranted.localNetwork(after: .connected) == .granted)
    }

    @Test func macOSBlockingTheAppMeansLocalNetworkIsNotAllowed() {
        #expect(PermissionStatus.notCheckedYet.localNetwork(after: .localNetworkBlocked) == .notGranted)
        #expect(PermissionStatus.granted.localNetwork(after: .localNetworkBlocked) == .notGranted)
    }

    /// A speaker that's off or has moved says nothing about the
    /// permission, so the last answer stands.
    @Test func otherStatusesKeepTheLastAnswer() {
        let saysNothing: [ConnectionStatus] = [.dormant, .noSpeaker, .searching, .connecting, .notConnected]
        for last in [PermissionStatus.granted, .notGranted, .notCheckedYet] {
            for status in saysNothing {
                #expect(last.localNetwork(after: status) == last, "\(last) after \(status)")
            }
        }
    }

    // MARK: - Newly granted (the media key tap starts again)

    @Test func becomingGrantedIsNew() {
        #expect(PermissionStatus.isNewlyGranted(from: .notGranted, to: .granted))
        #expect(PermissionStatus.isNewlyGranted(from: .notCheckedYet, to: .granted))
    }

    @Test func stayingGrantedOrLosingItIsNotNew() {
        #expect(!PermissionStatus.isNewlyGranted(from: .granted, to: .granted))
        #expect(!PermissionStatus.isNewlyGranted(from: .granted, to: .notGranted))
        #expect(!PermissionStatus.isNewlyGranted(from: .notGranted, to: .notGranted))
    }
}
