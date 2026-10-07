import Foundation

/// Persisted app configuration. Stored as JSON at ~/.kef-remote/config.json.
///
/// The nested structs below are the full schema.
public struct AppConfig: Codable, Equatable {
    public var speaker: SpeakerConfig?
    /// What the app sets on the speaker. A file from 0.2.0 or earlier has
    /// none: everything is Don't change.
    public var speakerSettings: SpeakerSettings
    public var lifecycle: LifecycleConfig
    public var network: NetworkConfig
    public var app: AppBehaviourConfig
    /// Auto or Manual. A file from before 0.2.0 has none: that means Auto.
    public var discovery: DiscoveryMode
    /// Whether he has finished the setup window. Nil in a file from before
    /// 0.4.0: ``Onboarding/isFinished(saved:speaker:accessibility:)``
    /// decides, and the app saves its answer.
    public var onboarding: OnboardingConfig?

    public init() {
        self.speaker = nil
        self.speakerSettings = SpeakerSettings()
        self.lifecycle = LifecycleConfig()
        self.network = NetworkConfig()
        self.app = AppBehaviourConfig()
        self.discovery = .auto
        self.onboarding = OnboardingConfig()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speaker = try container.decodeIfPresent(SpeakerConfig.self, forKey: .speaker)
        // Added after 0.2.0. An older file's unused "defaults" block is not
        // read: its input was optical for everyone, and carrying it over
        // would switch Wi-Fi and Bluetooth listeners to Optical.
        speakerSettings = try container.decodeIfPresent(SpeakerSettings.self, forKey: .speakerSettings) ?? SpeakerSettings()
        lifecycle = try container.decode(LifecycleConfig.self, forKey: .lifecycle)
        network = try container.decode(NetworkConfig.self, forKey: .network)
        app = try container.decode(AppBehaviourConfig.self, forKey: .app)
        // Added in 0.2.0: an older file keeps finding the speaker by itself.
        discovery = try container.decodeIfPresent(DiscoveryMode.self, forKey: .discovery) ?? .auto
        // Added in 0.4.0: left nil, as only the app can tell whether an
        // older file's owner has set up already (it needs Accessibility).
        onboarding = try container.decodeIfPresent(OnboardingConfig.self, forKey: .onboarding)
    }

    public struct SpeakerConfig: Codable, Equatable, Sendable {
        public var name: String?
        /// The model name from discovery, such as "SP3994" for an LSX
        /// (see ``SpeakerModel``). Saved from 0.3.0; older files have none.
        public var model: String?
        public var mac: String?
        public var lastKnownIp: String?

        public init(name: String? = nil, model: String? = nil, mac: String? = nil, lastKnownIp: String? = nil) {
            self.name = name
            self.model = model
            self.mac = mac
            self.lastKnownIp = lastKnownIp
        }
    }

    /// `"onboarding": {"finished": true}` once Done is clicked in setup.
    public struct OnboardingConfig: Codable, Equatable, Sendable {
        public var finished: Bool
        /// Set by Restart and continue on step 1 (``PermissionsStepContinue``),
        /// so the copy that starts next opens setup on step 2. Cleared
        /// once step 2 shows (``clearResume(onShowing:)``).
        public var resumeAtFindSpeaker: Bool

        public init(finished: Bool = false, resumeAtFindSpeaker: Bool = false) {
            self.finished = finished
            self.resumeAtFindSpeaker = resumeAtFindSpeaker
        }

        /// A block saved before Restart and continue existed has only
        /// `finished`: it doesn't resume.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            finished = try container.decode(Bool.self, forKey: .finished)
            resumeAtFindSpeaker = try container.decodeIfPresent(Bool.self, forKey: .resumeAtFindSpeaker) ?? false
        }

        /// Clear the resume flag as `step` shows, if it's the step it
        /// asked for.
        /// - Returns: True when it cleared it: save, and log it.
        public mutating func clearResume(onShowing step: OnboardingStep) -> Bool {
            guard resumeAtFindSpeaker, step == .findSpeaker else { return false }
            resumeAtFindSpeaker = false
            return true
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
