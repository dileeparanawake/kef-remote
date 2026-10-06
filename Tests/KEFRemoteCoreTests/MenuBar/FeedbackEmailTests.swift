import Foundation
import Testing
@testable import KEFRemoteCore

/// Send feedback…: when the menu shows it, the question about the log,
/// and the email it writes.
struct FeedbackEmailTests {

    private let lsx = AppConfig.SpeakerConfig(name: "LSX", model: "SP3994", mac: "AA:BB", lastKnownIp: "192.168.1.80")

    private func email(speaker: AppConfig.SpeakerConfig?) -> FeedbackEmail {
        FeedbackEmail(
            recipient: "me@example.com",
            appVersion: "0.3.0",
            build: "3",
            macOSVersion: "Version 26.0 (Build 25A100)",
            speaker: speaker
        )
    }

    // MARK: - Showing the item

    @Test func theItemSaysItAsksMore() {
        #expect(FeedbackEmail.menuTitle == "Send feedback…")
    }

    @Test func theItemShowsOnceThereIsAnAddress() {
        #expect(FeedbackEmail.isShown(recipient: "me@example.com"))
    }

    @Test func theItemIsHiddenWithoutAnAddress() {
        #expect(!FeedbackEmail.isShown(recipient: nil))
        #expect(!FeedbackEmail.isShown(recipient: ""))
    }

    @Test func todayThereIsNoAddress() {
        // Dileepa hasn't picked the address yet (6 Oct 2026).
        #expect(FeedbackEmail.recipient == nil)
        #expect(!FeedbackEmail.isShown)
        #expect(FeedbackEmail.today(appVersion: "0.3.0", build: "3", macOSVersion: "Version 26.0", speaker: lsx) == nil)
    }

    // MARK: - The question about the log

    @Test func theQuestionSaysWhatTheLogHolds() {
        #expect(FeedbackLogChoice.question == "Attach the log?")
        #expect(FeedbackLogChoice.detail == "It helps find what went wrong. It holds your speaker's IP address and serial number.")
    }

    @Test func theButtonsAreAttachDontAttachCancelInThatOrder() {
        #expect(FeedbackLogChoice.allCases.map(\.title) == ["Attach", "Don't attach", "Cancel"])
    }

    @Test func eachButtonMapsToItsChoice() {
        #expect(FeedbackLogChoice(buttonIndex: 0) == .attach)
        #expect(FeedbackLogChoice(buttonIndex: 1) == .dontAttach)
        #expect(FeedbackLogChoice(buttonIndex: 2) == .cancel)
        #expect(FeedbackLogChoice(buttonIndex: 3) == nil)
    }

    @Test func onlyCancelStopsTheEmail() {
        #expect(FeedbackLogChoice.attach.writesEmail)
        #expect(FeedbackLogChoice.dontAttach.writesEmail)
        #expect(!FeedbackLogChoice.cancel.writesEmail)
    }

    @Test func theLogIsAttachedOnlyIfTheyAgreeAndItExists() {
        let log = URL(fileURLWithPath: "/tmp/kef-remote.log")
        #expect(FeedbackLogChoice.attach.attachment(logFile: log, logExists: true) == log)
        #expect(FeedbackLogChoice.attach.attachment(logFile: log, logExists: false) == nil)
        #expect(FeedbackLogChoice.dontAttach.attachment(logFile: log, logExists: true) == nil)
        #expect(FeedbackLogChoice.cancel.attachment(logFile: log, logExists: true) == nil)
    }

    // MARK: - The email

    @Test func theSubjectNamesTheVersion() {
        #expect(email(speaker: lsx).subject == "KEF Remote feedback (0.3.0)")
    }

    @Test func itGoesToTheAddress() {
        #expect(email(speaker: lsx).recipient == "me@example.com")
    }

    @Test func theBodyFillsInTheFactsAndLeavesRoomForTheirWords() {
        #expect(email(speaker: lsx).body == """
            App: KEF Remote 0.3.0 (3)
            macOS: Version 26.0 (Build 25A100)
            Speaker: LSX (SP3994)

            What did you expect?


            What happened?


            """)
    }

    @Test func theSpeakerLineSaysWhenNoSpeakerIsFound() {
        #expect(FeedbackEmail.speakerLine(nil) == "not found yet")
        #expect(FeedbackEmail.speakerLine(AppConfig.SpeakerConfig(name: " ", model: "")) == "not found yet")
        #expect(email(speaker: nil).body.contains("Speaker: not found yet\n"))
    }

    /// A config saved before 0.3.0 has the name but no model.
    @Test func theSpeakerLineUsesWhateverItHas() {
        #expect(FeedbackEmail.speakerLine(AppConfig.SpeakerConfig(name: "LSX")) == "LSX")
        #expect(FeedbackEmail.speakerLine(AppConfig.SpeakerConfig(model: "SP3994")) == "SP3994")
    }

    @Test func theMailtoLinkCarriesTheSubjectAndBody() throws {
        let sent = email(speaker: lsx)
        let url = try #require(sent.mailtoURL)
        #expect(url.scheme == "mailto")
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.path == "me@example.com")
        let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(items["subject"] == sent.subject)
        #expect(items["body"] == sent.body)
    }

    /// Mail reads `+` as a space and `&` as the next field, so both are escaped.
    @Test func theMailtoLinkEscapesCharactersMailWouldMisread() throws {
        let sent = FeedbackEmail(recipient: "me@example.com", appVersion: "1+2&3=4", build: "#?", macOSVersion: "x", speaker: nil)
        let url = try #require(sent.mailtoURL)
        let query = try #require(url.query(percentEncoded: true))
        #expect(!query.contains("+"))
        #expect(query.components(separatedBy: "&").count == 2)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.queryItems?.first { $0.name == "subject" }?.value == "KEF Remote feedback (1+2&3=4)")
    }
}
