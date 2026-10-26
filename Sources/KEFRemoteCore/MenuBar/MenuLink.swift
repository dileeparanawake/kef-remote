import Foundation

/// A web link in the menu, between Settings… and Quit.
///
/// ```
/// Settings…              ⌘,
/// ─────────────
/// Buy me a coffee…          only once its page exists
/// Made by Dileepa ↗
/// ─────────────
/// Quit KEF Remote        ⌘Q
/// ```
public enum MenuLink: CaseIterable, Equatable, Sendable {
    /// The pay-what-you-want page (Ko-fi).
    case support
    /// Dileepa's site.
    case madeBy

    /// Dileepa's Ko-fi page. Set to nil and the Support item hides.
    static let supportURL: URL? = URL(string: "https://ko-fi.com/dileepabuilds")

    public var title: String {
        switch self {
        case .support: "Buy me a coffee…"
        case .madeBy: "Made by Dileepa ↗"
        }
    }

    public var url: URL? {
        switch self {
        case .support: Self.supportURL
        case .madeBy: URL(string: "https://www.dileeparanawake.com")
        }
    }

    /// The links the menu shows today.
    public static var shown: [MenuLink] { shown(supportURL: supportURL) }

    /// Support stays hidden until its page exists, so the menu never
    /// offers a dead click.
    static func shown(supportURL: URL?) -> [MenuLink] {
        supportURL == nil ? [.madeBy] : [.support, .madeBy]
    }
}
