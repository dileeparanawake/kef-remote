import AppKit
import KEFRemoteCore
import SwiftUI

/// A quiet link to the privacy notice (``PrivacyNotice``), in Settings'
/// footer and on setup's last step. A button rather than a SwiftUI
/// `Link`, so each click logs one line under the caller's category:
/// ```
/// Privacy clicked, opened https://github.com/…/PRIVACY.md
/// ```
struct PrivacyLink: View {
    let title: String
    let log: AppLogger

    var body: some View {
        Button(title) {
            let opened = NSWorkspace.shared.open(PrivacyNotice.url)
            log.info("\(title) clicked, \(opened ? "opened" : "could not open") \(PrivacyNotice.url.absoluteString)")
        }
        .buttonStyle(.link)
        .font(.caption)
    }
}
