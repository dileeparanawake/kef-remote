import Foundation

/// Persisted app configuration. Stored as JSON at ~/.kef-remote/config.json.
///
/// The nested structs below are the full schema.
public struct AppConfig: Codable, Equatable {
    public var speaker: SpeakerConfig?
    public var defaults: DefaultsConfig
    public var lifecycle: LifecycleConfig
    public var network: NetworkConfig
    public var app: AppBehaviourConfig

    public init() {
        self.speaker = nil
        self.defaults = DefaultsConfig()
        self.lifecycle = LifecycleConfig()
        self.network = NetworkConfig()
        self.app = AppBehaviourConfig()
    }

    public struct SpeakerConfig: Codable, Equatable, Sendable {
        public var name: String?
        public var mac: String?
        public var lastKnownIp: String?

        public init(name: String? = nil, mac: String? = nil, lastKnownIp: String? = nil) {
            self.name = name
            self.mac = mac
            self.lastKnownIp = lastKnownIp
        }
    }

    public struct DefaultsConfig: Codable, Equatable {
        public var input: InputSource
        public var standby: StandbyMode

        public init(input: InputSource = .optical, standby: StandbyMode = .never) {
            self.input = input
            self.standby = standby
        }
    }

    public struct LifecycleConfig: Codable, Equatable {
        public var powerOnWake: Bool
        public var powerOffSleep: Bool
        public var powerOffDelay: Int

        public init(powerOnWake: Bool = false, powerOffSleep: Bool = false, powerOffDelay: Int = 60) {
            self.powerOnWake = powerOnWake
            self.powerOffSleep = powerOffSleep
            self.powerOffDelay = powerOffDelay
        }
    }

    public struct NetworkConfig: Codable, Equatable {
        public var homeSSID: String?

        public init(homeSSID: String? = nil) {
            self.homeSSID = homeSSID
        }
    }

    public struct AppBehaviourConfig: Codable, Equatable {
        public var launchAtLogin: Bool

        public init(launchAtLogin: Bool = false) {
            self.launchAtLogin = launchAtLogin
        }
    }

    // MARK: - Persistence

    /// The app's config file: `~/.kef-remote/config.json`.
    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kef-remote")
            .appendingPathComponent("config.json")
    }

    /// Save the configuration as pretty-printed JSON to the given file URL.
    /// Makes the folder first if it is missing.
    public static func save(_ config: AppConfig, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    /// Load configuration from the given file URL.
    /// Returns a default configuration if the file does not exist.
    public static func load(from url: URL) throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppConfig()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }
}
