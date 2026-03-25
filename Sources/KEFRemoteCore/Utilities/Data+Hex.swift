import Foundation

extension Data {
    /// Formats bytes as space-separated uppercase hex pairs.
    /// e.g. `Data([0x47, 0x25, 0x80])` produces `"47 25 80"`
    public var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
