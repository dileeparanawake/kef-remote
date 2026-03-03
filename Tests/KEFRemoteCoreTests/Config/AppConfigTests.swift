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

    @Test func loadReturnsDefaultWhenFileDoesNotExist() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kef-remote-test-\(UUID().uuidString)")
        let filePath = testDir.appendingPathComponent("nonexistent.json")
        let config = try AppConfig.load(from: filePath)
        #expect(config.speaker == nil)
        #expect(config.defaults.input == .optical)
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

    @Test(.disabled("InputSource and StandbyMode use UInt8 raw values — string decoding requires custom Codable (see 2026-03-03-config-and-runtime-fixes.md)"))
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
