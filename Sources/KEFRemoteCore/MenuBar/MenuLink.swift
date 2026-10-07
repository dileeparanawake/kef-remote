import Foundation

/// A web link in the menu, between Settings… and Quit.
///
/// ```
/// Settings…              ⌘,
/// ─────────────
/// Support KEF Remote…        only once its page exists
/// Made by Dileepa ↗
/// ─────────────
/// Quit KEF Remote        ⌘Q
/// ```
public enum MenuLink: CaseIterable, Equatable, Sendable {
    /// The pay-what-you-want page.
    case support
    /// Dileepa's site.
    case madeBy

    /// The Gumroad page. Nil until Dileepa makes it; set it here and the
    /// Support item shows.
    static let supportURL: URL? = nil

    public var title: String {
        switch self {
        case .support: "Support KEF Remote…"
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
