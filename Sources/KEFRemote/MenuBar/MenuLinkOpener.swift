import AppKit
import KEFRemoteCore

extension MenuLink {
    /// Open the link's page in the browser: from the menu, and from
    /// Settings' About tab. Logs one line under the caller's category:
    /// ```
    /// menu: Made by Dileepa ↗ clicked, opened https://www.dileeparanawake.com
    /// ```
    /// - Parameter place: Where the click came from, first in the line.
    @MainActor
    func open(from place: String, log: AppLogger) {
        guard let url else {
            log.warning("\(place): \(title) clicked, but it has no page yet")
            return
        }
        let opened = NSWorkspace.shared.open(url)
        log.info("\(place): \(title) clicked, \(opened ? "opened" : "could not open") \(url.absoluteString)")
    }
}
