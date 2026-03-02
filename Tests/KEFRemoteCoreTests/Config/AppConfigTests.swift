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
}
