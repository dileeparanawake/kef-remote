import Foundation

/// The app's version, as Info.plist gives it: for Settings' About tab
/// and the feedback email.
public struct AppVersion: Equatable, Sendable {
    /// "0.3.0": `CFBundleShortVersionString`.
    public let short: String
    /// "3": `CFBundleVersion`.
    public let build: String

    /// - Parameter info: `Bundle.main.infoDictionary`. A missing entry
    ///   reads "unknown", so the line never has a gap.
    public init(info: [String: Any]?) {
        short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        build = info?["CFBundleVersion"] as? String ?? "unknown"
    }

    /// The app running now.
    public static var current: AppVersion { AppVersion(info: Bundle.main.infoDictionary) }

    /// "Version 0.3.0 (3)", in the About tab.
    public var aboutLine: String { "Version \(short) (\(build))" }
}
