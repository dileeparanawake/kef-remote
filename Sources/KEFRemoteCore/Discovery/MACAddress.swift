import Foundation

public enum MACAddress {
    /// "a1:b2-c3d4.e5f6" → "A1B2C3D4E5F6", so two ways of writing one MAC compare equal.
    public static func normalised(_ text: String) -> String {
        text.uppercased().filter { $0.isHexDigit }
    }
}
