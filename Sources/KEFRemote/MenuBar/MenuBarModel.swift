import Combine
import KEFRemoteCore

/// What the menu bar shows: whether the speaker is connected, and which one.
///
/// `AppDelegate` owns it and sets it as things happen. The menu bar
/// views only read it. Each real change is logged once, with its reason:
///
/// ```
/// [menubar] status connecting -> notConnected (speaker unreachable: …), red dot on
/// [menubar] status connecting -> connected (speaker answered), green dot for 4.0 seconds
/// ```
///
/// While it looks for the speaker, ``pulse`` fades the orange dot.
@MainActor
final class MenuBarModel: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .dormant
    @Published private(set) var speakerName: String?
    @Published private(set) var speakerIP: String?
    /// True for ``ConnectedFlash/duration`` after becoming connected.
    @Published private(set) var isFlashingConnected = false

    /// Fades the orange dot while it looks for the speaker.
    let pulse = MenuBarPulse()

    /// Ends the green dot; replaced when a new flash starts.
    private var flashEnd: Task<Void, Never>?

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    var presentation: MenuBarPresentation {
        MenuBarPresentation(status: status, speakerName: speakerName, ip: speakerIP, isFlashingConnected: isFlashingConnected)
    }

    /// Change the status. A change to the same status is ignored, so
    /// every command's reply doesn't fill the log. The red dot is logged
    /// when it comes or goes, and so is the green one.
    func set(_ newStatus: ConnectionStatus, reason: String) {
        guard newStatus != status else { return }
        let oldStatus = status
        let hadDot = presentation.needsAttention
        status = newStatus
        let hasDot = presentation.needsAttention
        let dotChange = hadDot == hasDot ? "" : ", red dot \(hasDot ? "on" : "off")"
        let flashes = ConnectedFlash.starts(from: oldStatus, to: newStatus)
        let flashNote = flashes ? ", green dot for \(ConnectedFlash.duration)" : ""
        log.info("status \(oldStatus.rawValue) -> \(newStatus.rawValue) (\(reason))\(dotChange)\(flashNote)")
        if flashes { flashConnected() }
        pulse.run(presentation.dot.pulses)
    }

    /// Show the green dot, then take it away after ``ConnectedFlash/duration``.
    private func flashConnected() {
        flashEnd?.cancel()
        isFlashingConnected = true
        flashEnd = Task { [weak self] in
            try? await Task.sleep(for: ConnectedFlash.duration)
            guard !Task.isCancelled else { return }
            self?.isFlashingConnected = false
        }
    }

    /// Show which speaker the app talks to.
    func showSpeaker(_ speaker: AppConfig.SpeakerConfig?) {
        guard speaker?.name != speakerName || speaker?.lastKnownIp != speakerIP else { return }
        speakerName = speaker?.name
        speakerIP = speaker?.lastKnownIp
        log.info("speaker \(speakerName ?? "unnamed") at \(speakerIP ?? "no IP")")
    }
}
