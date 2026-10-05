import Combine
import KEFRemoteCore

/// What the menu bar shows: the connection status and which speaker.
///
/// `AppDelegate` owns it and sets it as things happen. The menu bar
/// views only read it. Each real change is logged once, with its reason:
///
/// ```
/// [menubar] status ready -> ok (volumeUp succeeded)
/// ```
@MainActor
final class MenuBarModel: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .dormant
    @Published private(set) var speakerName: String?
    @Published private(set) var speakerIP: String?

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var presentation: MenuBarPresentation {
        MenuBarPresentation(status: status, speakerName: speakerName, ip: speakerIP)
    }

    /// Change the status. A change to the same status is ignored, so
    /// repeated successes don't fill the log.
    func set(_ newStatus: ConnectionStatus, reason: String) {
        guard newStatus != status else { return }
        log.info("status \(status.rawValue) -> \(newStatus.rawValue) (\(reason))")
        status = newStatus
    }

    /// Show which speaker the app talks to.
    func showSpeaker(_ speaker: AppConfig.SpeakerConfig?) {
        guard speaker?.name != speakerName || speaker?.lastKnownIp != speakerIP else { return }
        speakerName = speaker?.name
        speakerIP = speaker?.lastKnownIp
        log.info("speaker \(speakerName ?? "unnamed") at \(speakerIP ?? "no IP")")
    }
}
