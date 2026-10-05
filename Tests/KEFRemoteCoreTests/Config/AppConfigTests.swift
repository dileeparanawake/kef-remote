import Testing
import Foundation
@testable import KEFRemoteCore

struct AppConfigTests {

    @Test func defaultConfigHasSensibleDefaults() {
        let config = AppConfig()
        #expect(config.defaults.input == .optical)
        #expect(config.defaults.standby == .never)
        #expect(config.lifecycle.powerOnWake == false)
        #expect(config.lifecycle.powerOffSleep == false)
        #expect(config.lifecycle.powerOffDelay == 60)
        #expect(config.app.launchAtLogin == false)
    }

    @Test func saveAndLoad() throws {
        var config = AppConfig()
        config.speaker = .init(name: "Test Speaker", mac: "AA:BB:CC:DD:EE:FF", lastKnownIp: "192.168.1.42")
        config.defaults.input = .usb
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
        #expect(loaded.defaults.input == .usb)
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
        #expect(config.defaults.input == .optical)
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
        #expect(config.defaults.input == .optical)
        #expect(config.defaults.standby == .never)
        #expect(config.network.homeSSID == nil)
    }

    @Test(.disabled("InputSource and StandbyMode use UInt8 raw values — string decoding requires custom Codable"))
    func decodesConfigWithStringEnumValues() throws {
        // Config files should support human-readable strings like
        // "optical" and "never" instead of requiring integer raw
        // values (11 and 2). This test documents the expected
        // behaviour and will pass once custom Codable conformance
        // is added to InputSource and StandbyMode.
        let json = """
        {
            "app": { "launchAtLogin": false },
            "defaults": { "input": "optical", "standby": "never" },
            "lifecycle": {
                "powerOffDelay": 60,
                "powerOffSleep": false,
                "powerOnWake": false
            },
            "network": {},
            "speaker": { "lastKnownIp": "192.168.1.81" }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        #expect(config.defaults.input == .optical)
        #expect(config.defaults.standby == .never)
        #expect(config.speaker?.lastKnownIp == "192.168.1.81")
    }
}
