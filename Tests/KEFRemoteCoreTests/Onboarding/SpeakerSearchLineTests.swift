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
    @Test func aConnectedSpeakerShowsAsFoundAndConnected() {
        let shown = line(.connected, speaker: lsx)

        #expect(shown == .connected(name: "LSX", ip: "192.168.1.80"))
        #expect(shown.text == "Found LSX at 192.168.1.80. Connected.")
        #expect(!shown.isBusy)
        #expect(!shown.offersManual)
    }

    /// Hand test round 4: just after Find speaker, the line read
    /// "Checking the speaker at 192.168.1.80 answers…", as if that IP had
    /// been saved before. It says it was found, and is connecting.
    @Test func aSpeakerJustFoundSaysFoundAndConnecting() {
        let shown = line(.connecting, speaker: lsx)

        #expect(shown == .connecting(name: "LSX", ip: "192.168.1.80"))
        #expect(shown.text == "Found LSX at 192.168.1.80. Connecting…")
        #expect(shown.isBusy)
        #expect(!shown.offersManual)
    }

    /// Discovery always saves a name, so a speaker with none had its IP
    /// typed: it wasn't found, so the line doesn't say so.
    @Test func aTypedIPIsNotCalledFound() {
        let typed = AppConfig.SpeakerConfig(lastKnownIp: "10.0.0.5")

        #expect(line(.connecting, speaker: typed).text == "Connecting to the speaker at 10.0.0.5…")
        #expect(line(.connected, speaker: typed).text == "Connected to the speaker at 10.0.0.5.")
    }

    /// Found wins over an earlier search that found nothing.
    @Test func connectedWinsOverAnEarlierMiss() {
        #expect(line(.connected, speaker: lsx, searchFoundNothing: true) == .connected(name: "LSX", ip: "192.168.1.80"))
    }

    // MARK: - Looking

    @Test func searchingShowsASpinner() {
        let shown = line(.searching)

        #expect(shown == .searching)
        #expect(shown.text == "Looking for the speaker…")
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
    func beforeASearchItSaysNotFoundYet(connection: ConnectionStatus) {
        let shown = line(connection)

        #expect(shown == .notStarted)
        #expect(shown.text == "Not found yet")
        #expect(!shown.isBusy)
        #expect(!shown.offersManual)
    }
}
