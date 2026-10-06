import Combine
import KEFRemoteCore

/// What the menu bar shows: whether the speaker is connected, which one,
/// which input it's on, and whether Accessibility lets the volume keys work.
///
/// `AppDelegate` owns it and sets it as things happen. The menu bar
/// views only read it. Each real change is logged once, with its reason:
///
/// ```
/// [menubar] status connecting -> notConnected (speaker unreachable: …), red dot on
/// [menubar] status connecting -> connected (speaker answered), green dot for 4.0 seconds
/// [menubar] accessibility granted -> notGranted, red dot on
/// [menubar] speaker input Optical -> Wi-Fi
/// ```
///
/// While it looks for the speaker, ``pulse`` fades the orange dot.
@MainActor
final class MenuBarModel: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .dormant
    @Published private(set) var speakerName: String?
    @Published private(set) var speakerIP: String?
    /// Which speaker it is, for the inputs Input ▸ lists.
    @Published private(set) var speakerModel: SpeakerModel = .other
    /// The speaker's source byte as last read or written, for the tick in
    /// Input ▸. Nil before the first read, and once the connection drops.
    @Published private(set) var speakerSource: SourceByte?
    /// True for ``ConnectedFlash/duration`` after becoming connected.
    @Published private(set) var isFlashingConnected = false

    /// Fades the orange dot while it looks for the speaker.
    let pulse = MenuBarPulse()

    /// Ends the green dot; replaced when a new flash starts.
    private var flashEnd: Task<Void, Never>?

    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    /// Whether the volume keys may reach the speaker: off, it's a red dot.
    @Published private(set) var accessibility: PermissionStatus

    /// - Parameter accessibility: As macOS reports it at launch, so the
    ///   first change logged is a real one.
    init(accessibility: PermissionStatus) {
        self.accessibility = accessibility
    }

    var presentation: MenuBarPresentation {
        MenuBarPresentation(
            status: status,
            accessibility: accessibility,
            speakerName: speakerName,
            ip: speakerIP,
            isFlashingConnected: isFlashingConnected
        )
    }

    var inputMenu: InputMenu {
        InputMenu(speakerInput: speakerSource?.input, isConnected: presentation.isConnected, inputs: speakerModel.inputs)
    }

    /// Show the speaker's source byte as the controller last saw it. Logs
    /// only a change of input, the part the menu shows.
    func showSource(_ source: SourceByte?) {
        let oldInput = speakerSource?.input
        speakerSource = source
        guard source?.input != oldInput else { return }
        log.info("speaker input \(oldInput?.label ?? "unknown") -> \(source?.input.label ?? "unknown")")
    }

    /// Show Accessibility as ``PermissionsModel`` last saw it. Logs only a
    /// change, and whether it moved the red dot.
    func showAccessibility(_ newStatus: PermissionStatus) {
        guard newStatus != accessibility else { return }
        let old = accessibility
        let hadDot = presentation.needsAttention
        accessibility = newStatus
        let hasDot = presentation.needsAttention
        let dotChange = hadDot == hasDot ? "" : ", red dot \(hasDot ? "on" : "off")"
        log.info("accessibility \(old.rawValue) -> \(newStatus.rawValue)\(dotChange)")
        pulse.run(presentation.dot.pulses)
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
        let model = SpeakerModel(speaker)
        guard speaker?.name != speakerName || speaker?.lastKnownIp != speakerIP || model != speakerModel else { return }
        speakerName = speaker?.name
        speakerIP = speaker?.lastKnownIp
        speakerModel = model
        log.info("speaker \(speakerName ?? "unnamed") at \(speakerIP ?? "no IP") (\(model.label))")
    }
}
