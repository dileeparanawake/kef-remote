import Testing
import Foundation
@testable import KEFRemoteCore

struct AppConfigTests {

    @Test func defaultConfigHasSensibleDefaults() {
        let config = AppConfig()
        #expect(config.speakerSettings == SpeakerSettings())
        #expect(config.lifecycle.powerOnWake == false)
        #expect(config.lifecycle.powerOffSleep == false)
        #expect(config.lifecycle.powerOffDelay == 60)
        #expect(config.app.launchAtLogin == false)
    }

    @Test func saveAndLoad() throws {
        var config = AppConfig()
        config.speaker = .init(name: "Test Speaker", mac: "AA:BB:CC:DD:EE:FF", lastKnownIp: "192.168.1.42")
        config.speakerSettings.powerOnInput = .usb
        config.network.homeSSID = "TestNetwork"

        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let filePath = testDir.appendingPathComponent("config.json")
        try AppConfig.save(config, to: filePath)

        let loaded = try AppConfig.load(from: filePath)
        #expect(loaded.speaker?.name == "Test Speaker")
        #expect(loaded.speaker?.mac == "AA:BB:CC:DD:EE:FF")
        #expect(loaded.speakerSettings.powerOnInput == .usb)
        #expect(loaded.network.homeSSID == "TestNetwork")
    }

    @Test func saveMakesAMissingFolder() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }

        let filePath = testDir.appendingPathComponent("nested/config.json")
        try AppConfig.save(AppConfig(), to: filePath)

        #expect(try AppConfig.load(from: filePath) == AppConfig())
    }

    @Test func theDefaultFileIsConfigJSONInTheDotFolder() {
        #expect(AppConfig.defaultFileURL.path.hasSuffix("/.kef-remote/config.json"))
    }

    @Test func loadReturnsDefaultWhenFileDoesNotExist() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        let filePath = testDir.appendingPathComponent("nonexistent.json")
        let config = try AppConfig.load(from: filePath)
        #expect(config.speaker == nil)
        #expect(config.speakerSettings.powerOnInput == .dontChange)
    }

    // MARK: - Discovery mode

    @Test func discoveryIsAutoByDefault() {
        #expect(AppConfig().discovery == .auto)
    }

    /// A config.json written before discovery mode existed (like the one
    /// on Dileepa's Mac today) has no "discovery" key: it means Auto.
    @Test func aConfigWithoutDiscoveryMeansAuto() throws {
        let json = """
        {
            "app": { "launchAtLogin": false },
            "defaults": { "input": 11, "standby": 2 },
            "lifecycle": { "powerOffDelay": 60, "powerOffSleep": false, "powerOnWake": false },
            "network": {},
            "speaker": { "lastKnownIp": "192.168.1.80", "mac": "84171511907E", "name": "LSX" }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)

        #expect(config.discovery == .auto)
        #expect(config.speaker?.name == "LSX")
    }

    @Test func manualDiscoveryIsSavedAndLoaded() throws {
        var config = AppConfig()
        config.discovery = .manual
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        let filePath = testDir.appendingPathComponent("config.json")

        try AppConfig.save(config, to: filePath)

        #expect(try String(contentsOf: filePath, encoding: .utf8).contains("\"discovery\" : \"manual\""))
        #expect(try AppConfig.load(from: filePath).discovery == .manual)
    }

    // MARK: - Speaker settings

    /// Every config.json up to 0.2.0 holds a "defaults" block that
    /// nothing read, with "input": 11 (optical) written by default. It is
    /// dropped, not carried over: carrying it over would switch a Wi-Fi or
    /// Bluetooth listener to Optical the first time the app turns the
    /// speaker on. Everyone starts at Don't change.
    @Test func anOldDefaultsBlockIsDroppedAndEveryoneStartsAtDontChange() throws {
        let json = """
        {
            "app": { "launchAtLogin": false },
            "defaults": { "input": 11, "standby": 2 },
            "discovery": "auto",
            "lifecycle": { "powerOffDelay": 60, "powerOffSleep": false, "powerOnWake": false },
            "network": {},
            "speaker": { "lastKnownIp": "192.168.1.80", "mac": "84171511907E", "name": "LSX" }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)

        #expect(config.speakerSettings == SpeakerSettings())
        #expect(config.speaker?.name == "LSX")
    }

    @Test func savingDropsTheOldDefaultsBlock() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        let filePath = testDir.appendingPathComponent("config.json")

        try AppConfig.save(AppConfig(), to: filePath)

        let saved = try String(contentsOf: filePath, encoding: .utf8)
        #expect(!saved.contains("\"defaults\""))
        #expect(saved.contains("\"powerOnInput\" : \"dontChange\""))
    }

    // MARK: - Config decoding edge cases

    @Test func decodesConfigWithoutSpeakerSection() throws {
        // A config file may not have a speaker section if the user
        // hasn't discovered or configured a speaker yet. The speaker
        // property is optional, so this should decode successfully.
        let json = """
        {
            "app": { "launchAtLogin": false },
            "defaults": { "input": 11, "standby": 2 },
            "lifecycle": {
                "powerOffDelay": 60,
                "powerOffSleep": false,
                "powerOnWake": false
            },
            "network": {}
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        #expect(config.speaker == nil)
        #expect(config.network.homeSSID == nil)
    }
}
