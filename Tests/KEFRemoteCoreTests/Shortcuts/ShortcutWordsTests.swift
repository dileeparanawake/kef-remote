import Testing
@testable import KEFRemoteCore

/// A recorded shortcut in words, as the README writes them: "Cmd+Shift+O".
struct ShortcutWordsTests {

    @Test func thePowerShortcutReadsAsTheReadmeWritesIt() {
        #expect(ShortcutWords.words(fromSymbols: "⇧⌘O") == "Cmd+Shift+O")
    }

    @Test(arguments: [
        ("⌃⌥P", "Option+Control+P"),
        ("⌃⇧⌘F5", "Cmd+Shift+Control+F5"),
        ("⌥Space", "Option+Space"),
        ("O", "O"),
    ])
    func everyModifierHasAName(symbols: String, words: String) {
        #expect(ShortcutWords.words(fromSymbols: symbols) == words)
    }
}
