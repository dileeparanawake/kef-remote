/// A recorded shortcut in words, as the README writes them, so setup's
/// last step reads "Cmd+Shift+O turns it on and off." rather than "⇧⌘O".
public enum ShortcutWords {
    /// macOS's modifier symbols and their names, in the order the README
    /// writes them ("Cmd + Shift + O").
    private static let modifiers: [(symbol: Character, name: String)] = [
        ("⌘", "Cmd"), ("⇧", "Shift"), ("⌥", "Option"), ("⌃", "Control"),
    ]

    /// - Parameter symbols: A shortcut as KeyboardShortcuts prints it, such
    ///   as "⇧⌘O": modifier symbols, then the key.
    public static func words(fromSymbols symbols: String) -> String {
        let names = modifiers.filter { symbols.contains($0.symbol) }.map(\.name)
        let key = String(symbols.filter { character in !modifiers.contains { $0.symbol == character } })
        return (names + [key]).joined(separator: "+")
    }
}
