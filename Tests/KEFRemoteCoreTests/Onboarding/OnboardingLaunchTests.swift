import Foundation
import Testing
@testable import KEFRemoteCore

/// Whether onboarding is finished, and which window opens at launch.
struct OnboardingLaunchTests {

    private let lsx = AppConfig.SpeakerConfig(name: "LSX", lastKnownIp: "192.168.1.80")

    // MARK: - Finished, from config.json

    @Test func aSavedFlagDecides() {
        #expect(Onboarding.isFinished(saved: .init(finished: true), speaker: nil, accessibility: .notGranted))
        #expect(!Onboarding.isFinished(saved: .init(finished: false), speaker: lsx, accessibility: .granted))
    }

    /// A file from before onboarding: someone with a speaker saved and the
    /// volume keys allowed has set up already, so isn't onboarded again.
    @Test func anOlderFileWithASpeakerAndAccessibilityCountsAsFinished() {
        #expect(Onboarding.isFinished(saved: nil, speaker: lsx, accessibility: .granted))
    }

    @Test func anOlderFileWithoutASpeakerIsNotFinished() {
        #expect(!Onboarding.isFinished(saved: nil, speaker: nil, accessibility: .granted))
        let namedWithNoIP = AppConfig.SpeakerConfig(name: "LSX")
        #expect(!Onboarding.isFinished(saved: nil, speaker: namedWithNoIP, accessibility: .granted))
    }

    @Test func anOlderFileWithoutAccessibilityIsNotFinished() {
        #expect(!Onboarding.isFinished(saved: nil, speaker: lsx, accessibility: .notGranted))
    }

    // MARK: - Which window opens at launch

    @Test func allStepsOpenUntilOnboardingIsFinished() {
        #expect(Onboarding.windowAtLaunch(isFinished: false, resumeAtFindSpeaker: false, accessibility: .granted) == .resumeAllSteps)
        #expect(Onboarding.windowAtLaunch(isFinished: false, resumeAtFindSpeaker: false, accessibility: .notGranted) == .resumeAllSteps)
    }

    @Test func onceFinishedOnlyPermissionsOpenWhileAccessibilityIsMissing() {
        #expect(Onboarding.windowAtLaunch(isFinished: true, resumeAtFindSpeaker: false, accessibility: .notGranted) == .permissionsOnly)
    }

    @Test func onceFinishedNothingOpensWithAccessibilityAllowed() {
        #expect(Onboarding.windowAtLaunch(isFinished: true, resumeAtFindSpeaker: false, accessibility: .granted) == nil)
    }

    // MARK: - Saved in config.json

    @Test func aNewConfigIsNotFinished() {
        #expect(AppConfig().onboarding == .init(finished: false))
    }

    @Test func anOlderFileHasNoOnboarding() throws {
        let json = """
        {
            "app": { "launchAtLogin": false },
            "lifecycle": { "powerOffDelay": 60, "powerOffSleep": false, "powerOnWake": false },
            "network": {},
            "speaker": { "lastKnownIp": "192.168.1.80", "name": "LSX" }
        }
        """.data(using: .utf8)!

        #expect(try JSONDecoder().decode(AppConfig.self, from: json).onboarding == nil)
    }

    @Test func finishedIsSavedAndLoaded() throws {
        var config = AppConfig()
        config.onboarding = .init(finished: true)
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        let filePath = testDir.appendingPathComponent("config.json")

        try AppConfig.save(config, to: filePath)

        #expect(try String(contentsOf: filePath, encoding: .utf8).contains("\"finished\" : true"))
        #expect(try AppConfig.load(from: filePath).onboarding == .init(finished: true))
    }
}
