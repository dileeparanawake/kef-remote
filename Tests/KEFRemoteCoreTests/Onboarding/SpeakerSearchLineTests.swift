import Testing
@testable import KEFRemoteCore

/// The line under Find speaker in step 2: looking, found, or not found.
struct SpeakerSearchLineTests {

    private let lsx = AppConfig.SpeakerConfig(name: "LSX", lastKnownIp: "192.168.1.80")

    private func line(
        _ connection: ConnectionStatus,
        speaker: AppConfig.SpeakerConfig? = nil,
        searchFoundNothing: Bool = false
    ) -> SpeakerSearchLine {
        SpeakerSearchLine(connection: connection, speaker: speaker, searchFoundNothing: searchFoundNothing)
    }

    // MARK: - Found

    /// The app may have found and connected to the speaker by itself
    /// before he reaches step 2: it shows as found straight away.
    @Test func aConnectedSpeakerShowsAsFound() {
        let shown = line(.connected, speaker: lsx)

        #expect(shown == .found(name: "LSX", ip: "192.168.1.80"))
        #expect(shown.text == "Found LSX at 192.168.1.80")
        #expect(!shown.isBusy)
        #expect(!shown.offersManual)
    }

    @Test func aSpeakerWithNoNameIsTheSpeaker() {
        #expect(line(.connected, speaker: .init(lastKnownIp: "10.0.0.5")).text == "Found the speaker at 10.0.0.5")
    }

    /// Found wins over an earlier search that found nothing.
    @Test func connectedWinsOverAnEarlierMiss() {
        #expect(line(.connected, speaker: lsx, searchFoundNothing: true) == .found(name: "LSX", ip: "192.168.1.80"))
    }

    // MARK: - Looking

    @Test func searchingShowsASpinner() {
        let shown = line(.searching)

        #expect(shown == .searching)
        #expect(shown.text == "Looking for the speaker…")
        #expect(shown.isBusy)
    }

    @Test func checkingAnIPShowsASpinner() {
        let shown = line(.connecting, speaker: lsx)

        #expect(shown == .checking(ip: "192.168.1.80"))
        #expect(shown.text == "Checking the speaker at 192.168.1.80 answers…")
        #expect(shown.isBusy)
    }

    // MARK: - Not found

    @Test func aSearchThatFoundNothingSaysWhatToCheckAndOffersManual() {
        let shown = line(.noSpeaker, searchFoundNothing: true)

        #expect(shown == .notFound)
        #expect(shown.text == "Not found: check it's on and on this network")
        #expect(shown.offersManual)
    }

    /// After a miss, the app checks the saved IP again: the miss stays
    /// on screen until that check answers.
    @Test func aMissStaysWhileTheSavedIPIsCheckedAgain() {
        #expect(line(.connecting, speaker: lsx, searchFoundNothing: true) == .notFound)
    }

    @Test func aSavedIPThatDoesNotAnswerSaysWhatToCheck() {
        let shown = line(.notConnected, speaker: lsx)

        #expect(shown == .noAnswer(ip: "192.168.1.80"))
        #expect(shown.text == "No answer at 192.168.1.80: check it's on and on this network")
        #expect(shown.offersManual)
    }

    @Test func blockedLocalNetworkPointsBackToStepOne() {
        let shown = line(.localNetworkBlocked, speaker: lsx, searchFoundNothing: true)

        #expect(shown == .localNetworkBlocked)
        #expect(shown.text == "Local Network is blocked: click Back and allow it")
        #expect(!shown.offersManual)
    }

    // MARK: - Not started

    @Test(arguments: [ConnectionStatus.noSpeaker, .dormant])
    func nothingShowsBeforeASearch(connection: ConnectionStatus) {
        let shown = line(connection)

        #expect(shown == .notStarted)
        #expect(shown.text == nil)
        #expect(!shown.isBusy)
    }
}
