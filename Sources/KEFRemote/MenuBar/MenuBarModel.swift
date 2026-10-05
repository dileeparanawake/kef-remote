import Combine
import KEFRemoteCore

/// What the menu bar shows: whether the speaker is connected, and which one.
///
/// `AppDelegate` owns it and sets it as things happen. The menu bar
/// views only read it. Each real change is logged once, with its reason:
///
/// ```
/// [menubar] status connecting -> notConnected (speaker unreachable: …), red dot on
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
    /// every command's reply doesn't fill the log. The red dot is logged
    /// when it comes or goes.
    func set(_ newStatus: ConnectionStatus, reason: String) {
        guard newStatus != status else { return }
        let oldStatus = status
        let hadDot = presentation.needsAttention
        status = newStatus
        let hasDot = presentation.needsAttention
        let dotChange = hadDot == hasDot ? "" : ", red dot \(hasDot ? "on" : "off")"
        log.info("status \(oldStatus.rawValue) -> \(newStatus.rawValue) (\(reason))\(dotChange)")
    }

    /// Show which speaker the app talks to.
    func showSpeaker(_ speaker: AppConfig.SpeakerConfig?) {
        guard speaker?.name != speakerName || speaker?.lastKnownIp != speakerIP else { return }
        speakerName = speaker?.name
        speakerIP = speaker?.lastKnownIp
        log.info("speaker \(speakerName ?? "unnamed") at \(speakerIP ?? "no IP")")
    }
}
