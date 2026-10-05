import AppKit
import KEFRemoteCore

/// Draws the menu bar icon: an SF Symbol at the size of the system's own
/// menu bar icons, with a red dot bottom-right when something needs him,
/// a green one for a moment after it connects, or an orange one while it
/// looks for the speaker (``MenuBarDot``).
///
/// ```
/// no dot                       dot
/// ┌──────┐                     ┌──────┐
/// │ spkr │  template image:    │ spkr │  drawn image: speaker in the
/// │      │  macOS tints it     │    ● │  menu bar's text colour, red dot
/// └──────┘                     └──────┘
/// ```
///
/// A template image can't hold a colour, so the dot version is drawn by
/// hand. It draws when AppKit draws it, so the speaker matches the menu
/// bar it lands on, light or dark.
enum MenuBarIconImage {
    /// SF Symbol point size. At 13pt the speaker symbols are 16 to 17pt
    /// tall, the size of the system's own menu bar icons.
    static let symbolPointSize: CGFloat = 13
    /// Big enough to see at a glance, small enough to leave the speaker
    /// readable. 5pt read too small in Round 3 (5 Oct); 6pt is 12 whole
    /// pixels on a Retina screen.
    static let dotDiameter: CGFloat = 6
    /// Clear ring cut round the dot, so it doesn't merge into the speaker.
    static let dotGap: CGFloat = 1

    /// - Parameter dotOpacity: How strongly the dot shows, for the pulse
    ///   (``SearchingPulse``); 1 for a steady dot.
    static func make(symbolName: String, dot: MenuBarDot, dotOpacity: Double = 1, accessibilityLabel: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)?
            .withSymbolConfiguration(config) ?? NSImage()

        guard let dotColour = colour(of: dot) else {
            symbol.isTemplate = true
            return symbol
        }

        let image = NSImage(size: symbol.size, flipped: false) { rect in
            drawSpeaker(symbol, in: rect)
            dotColour.withAlphaComponent(dotOpacity).setFill()
            NSBezierPath(ovalIn: dotRect(in: rect)).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityLabel
        return image
    }

    /// The dot's colour, or nil for no dot.
    private static func colour(of dot: MenuBarDot) -> NSColor? {
        switch dot {
        case .none: nil
        case .needsAttention: .systemRed
        case .justConnected: .systemGreen
        case .searching: .systemOrange
        }
    }

    /// The speaker in the menu bar's text colour, with a clear ring where
    /// the dot goes. The transparency layer keeps the cut-out to the speaker.
    private static func drawSpeaker(_ symbol: NSImage, in rect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.cgContext.endTransparencyLayer() }

        symbol.draw(in: rect)
        menuBarTextColour().setFill()
        rect.fill(using: .sourceAtop)

        let ring = dotRect(in: rect).insetBy(dx: -dotGap, dy: -dotGap)
        context.compositingOperation = .clear
        NSBezierPath(ovalIn: ring).fill()
    }

    /// Black on a light menu bar, white on a dark one, as macOS draws a
    /// template icon. Read from the appearance being drawn into.
    private static func menuBarTextColour() -> NSColor {
        let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? .white : .black
    }

    /// Bottom-right corner (the image isn't flipped, so y = 0 is the bottom).
    private static func dotRect(in rect: NSRect) -> NSRect {
        NSRect(x: rect.maxX - dotDiameter, y: rect.minY, width: dotDiameter, height: dotDiameter)
    }
}
