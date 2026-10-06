import Foundation

/// The email Send feedback… writes to Dileepa. No server and no tracking:
/// the user's own mail app sends it, and they see every word first.
///
/// ```
/// To:      FeedbackEmail.recipient
/// Subject: KEF Remote feedback (0.3.0)
///
/// App: KEF Remote 0.3.0 (3)
/// macOS: Version 26.0 (Build 25A100)
/// Speaker: LSX (SP3994)
///
/// What did you expect?
///
///
/// What happened?
/// ```
///
/// The item sits under Made by Dileepa ↗, and stays hidden while
/// ``recipient`` is nil, so the menu never offers a dead click.
public struct FeedbackEmail: Equatable, Sendable {
    /// Where feedback goes. Dileepa picks the address; set it here and
    /// Send feedback… shows.
    static let recipient: String? = nil

    public static let menuTitle = "Send feedback…"

    /// Whether the menu shows Send feedback… today.
    public static var isShown: Bool { isShown(recipient: recipient) }

    static func isShown(recipient: String?) -> Bool {
        !(recipient ?? "").isEmpty
    }

    public let recipient: String
    public let subject: String
    public let body: String

    init(recipient: String, appVersion: String, build: String, macOSVersion: String, speaker: AppConfig.SpeakerConfig?) {
        self.recipient = recipient
        subject = "KEF Remote feedback (\(appVersion))"
        body = """
            App: KEF Remote \(appVersion) (\(build))
            macOS: \(macOSVersion)
            Speaker: \(Self.speakerLine(speaker))

            What did you expect?


            What happened?


            """
    }

    /// The email to ``recipient``, or nil while there's no address.
    public static func today(appVersion: String, build: String, macOSVersion: String, speaker: AppConfig.SpeakerConfig?) -> FeedbackEmail? {
        guard let recipient, isShown(recipient: recipient) else { return nil }
        return FeedbackEmail(recipient: recipient, appVersion: appVersion, build: build, macOSVersion: macOSVersion, speaker: speaker)
    }

    /// "LSX (SP3994)": the name the speaker gives itself, then the model
    /// discovery read. A config from before 0.3.0 has only the name.
    static func speakerLine(_ speaker: AppConfig.SpeakerConfig?) -> String {
        let name = (speaker?.name ?? "").trimmingCharacters(in: .whitespaces)
        let model = (speaker?.model ?? "").trimmingCharacters(in: .whitespaces)
        switch (name.isEmpty, model.isEmpty) {
        case (false, false): return "\(name) (\(model))"
        case (false, true): return name
        case (true, false): return model
        case (true, true): return "not found yet"
        }
    }

    /// The same email as a `mailto:` link, for when no mail app takes it
    /// through the share service. A link can't carry the log.
    public var mailtoURL: URL? {
        URL(string: "mailto:\(recipient)?subject=\(Self.escaped(subject))&body=\(Self.escaped(body))")
    }

    /// Mail apps read `+` as a space and `&`, `=`, `#` and `?` as the
    /// link's own punctuation, so those are escaped as well.
    private static let mailtoValueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&=#?"))

    private static func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: mailtoValueAllowed) ?? value
    }
}

/// The question before the email: attach the log or not.
///
/// ```
/// Attach the log?
/// It helps find what went wrong. It holds your
/// speaker's IP address and serial number.
///      [Cancel]  [Don't attach]  [Attach]
/// ```
public enum FeedbackLogChoice: CaseIterable, Equatable, Sendable {
    case attach
    case dontAttach
    case cancel

    public static let question = "Attach the log?"
    /// Says what's in the log, so they choose knowing.
    public static let detail = "It helps find what went wrong. It holds your speaker's IP address and serial number."

    /// The buttons, added in ``allCases`` order: Attach is the default.
    public var title: String {
        switch self {
        case .attach: "Attach"
        case .dontAttach: "Don't attach"
        case .cancel: "Cancel"
        }
    }

    /// The choice for the alert's button at `buttonIndex` (0 is the first
    /// button added).
    public init?(buttonIndex: Int) {
        guard Self.allCases.indices.contains(buttonIndex) else { return nil }
        self = Self.allCases[buttonIndex]
    }

    /// Cancel closes the question and writes nothing.
    public var writesEmail: Bool { self != .cancel }

    /// The log to attach: only if they agreed, and only if it's there.
    public func attachment(logFile: URL, logExists: Bool) -> URL? {
        self == .attach && logExists ? logFile : nil
    }
}
