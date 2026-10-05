import Foundation

/// Checks an IP address typed into settings.
public enum SpeakerIP {
    /// The trimmed IPv4 address, or nil when the text is not one.
    public static func parse(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.allSatisfy(\.isASCIIDigit),
                  let number = Int(part), number <= 255
            else { return nil }
        }
        return trimmed
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
