import Foundation

/// The parts of a UPnP description.xml that discovery uses.
///
/// A KEF speaker's `serialNumber` is its MAC address with no separators.
public struct SpeakerDescription: Equatable, Sendable {
    public let manufacturer: String?
    public let friendlyName: String?
    public let modelName: String?
    public let serialNumber: String?

    /// True when the maker is KEF. This is the gate: other renderers are dropped.
    public var isKEF: Bool {
        let maker = (manufacturer ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        return maker == "KEF" || maker.hasPrefix("KEF ")
    }

    /// True when the serial number is this MAC, however the MAC is written.
    public func matches(mac: String) -> Bool {
        guard let serialNumber else { return false }
        let wanted = MACAddress.normalised(mac)
        return !wanted.isEmpty && MACAddress.normalised(serialNumber) == wanted
    }

    /// Parse description.xml. Takes the first of each field (the root device).
    /// Returns nil when the XML is broken.
    public static func parse(_ data: Data) -> SpeakerDescription? {
        let reader = FirstValueReader(wanted: ["manufacturer", "friendlyName", "modelName", "serialNumber"])
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else { return nil }
        return SpeakerDescription(
            manufacturer: reader.values["manufacturer"],
            friendlyName: reader.values["friendlyName"],
            modelName: reader.values["modelName"],
            serialNumber: reader.values["serialNumber"]
        )
    }
}

/// Collects the text of the first element with each wanted name.
private final class FirstValueReader: NSObject, XMLParserDelegate {
    private let wanted: Set<String>
    private var current: String?
    private var text = ""
    private(set) var values: [String: String] = [:]

    init(wanted: Set<String>) {
        self.wanted = wanted
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if wanted.contains(name), values[name] == nil {
            current = name
            text = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        guard name == current else { return }
        values[name] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        current = nil
    }
}
