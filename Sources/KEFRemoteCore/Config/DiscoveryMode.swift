/// How the app finds the speaker's IP. Saved in config.json as
/// `"discovery": "auto"` or `"manual"`.
public enum DiscoveryMode: String, Codable, CaseIterable, Sendable {
    /// The app finds the speaker, and looks again when its IP changes.
    case auto
    /// The user types the IP in Settings; the app never looks by itself.
    case manual

    /// Whether the app may look for the speaker on its own: at launch with
    /// no IP, or when the saved IP stops answering. A search the user asks
    /// for (Find speaker, Discover) runs in either mode.
    public var searchesBySelf: Bool { self == .auto }
}
