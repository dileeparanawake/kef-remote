import AppKit
import KEFRemoteCore

/// Send feedback… in the menu: asks whether to attach the log
/// (``FeedbackLogChoice``), then opens the email (``FeedbackEmail``) in
/// the user's mail app. If no mail app takes it, a `mailto:` link opens
/// instead, without the log.
///
/// Logged under `menubar`, one line per choice and outcome:
///
/// ```
/// [menubar] feedback: Attach chosen
/// [menubar] feedback: email opened in the mail app, log attached
/// [menubar] feedback: no mail app took the email; opened a mailto: link, so the log couldn't be attached
/// ```
@MainActor
struct FeedbackSender {
    private let log = AppLogger(subsystem: "com.kef-remote", category: "menubar")

    /// - Parameter speaker: The saved speaker, for the email's Speaker line.
    func send(speaker: AppConfig.SpeakerConfig?) {
        let info = Bundle.main.infoDictionary
        guard let email = FeedbackEmail.today(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            build: info?["CFBundleVersion"] as? String ?? "unknown",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            speaker: speaker
        ) else {
            log.warning("feedback: no address set, so no email")
            return
        }

        let choice = askAboutLog()
        log.info("feedback: \(choice.title) chosen")
        guard choice.writesEmail else { return }

        let logFile = LogFileWriter.defaultFileURL
        let logExists = FileManager.default.fileExists(atPath: logFile.path)
        if choice == .attach && !logExists {
            log.warning("feedback: no log file at \(logFile.path), so the email goes without it")
        }
        compose(email, attaching: choice.attachment(logFile: logFile, logExists: logExists))
    }

    /// Shows the question. The app has no Dock icon, so it comes to the
    /// front first, or the alert would open behind other windows.
    private func askAboutLog() -> FeedbackLogChoice {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = FeedbackLogChoice.question
        alert.informativeText = FeedbackLogChoice.detail
        for choice in FeedbackLogChoice.allCases {
            alert.addButton(withTitle: choice.title)
        }
        let buttonIndex = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return FeedbackLogChoice(buttonIndex: buttonIndex) ?? .cancel
    }

    private func compose(_ email: FeedbackEmail, attaching logFile: URL?) {
        var items: [Any] = [email.body]
        if let logFile { items.append(logFile) }

        if let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: items) {
            service.recipients = [email.recipient]
            service.subject = email.subject
            service.perform(withItems: items)
            log.info("feedback: email opened in the mail app, \(logFile == nil ? "no log" : "log attached")")
            return
        }

        guard let url = email.mailtoURL else {
            log.error("feedback: no mail app took the email, and the mailto: link couldn't be made")
            return
        }
        let opened = NSWorkspace.shared.open(url)
        let logNote = logFile == nil ? "" : ", so the log couldn't be attached"
        log.info("feedback: no mail app took the email; \(opened ? "opened" : "could not open") a mailto: link\(logNote)")
    }
}
