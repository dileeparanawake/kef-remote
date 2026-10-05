import Foundation

/// One device's answer to an SSDP search.
public struct SearchResponse: Equatable, Sendable {
    /// Header names are stored upper-case, so lookups ignore case.
    public let headers: [String: String]

    /// Where the device's description.xml lives.
    public let location: URL

    /// The `ST` header: what kind of device this reply is for.
    public var searchTarget: String? { headers["ST"] }

    /// The IP address in `LOCATION`.
    public var host: String? { location.host }

    /// True when the reply is for a MediaRenderer, the kind KEF speakers are.
    public var isMediaRenderer: Bool { searchTarget == SSDPSearch.mediaRenderer }

    /// Parse a reply. Returns nil for anything that is not an
    /// `HTTP/1.1 200 OK` with a `LOCATION` URL (another app's search, say).
    public static func parse(_ data: Data) -> SearchResponse? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\r\n")
        guard let statusLine = lines.first, statusLine.hasPrefix("HTTP/1.1 200") else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).uppercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        guard let locationText = headers["LOCATION"],
              let location = URL(string: locationText),
              location.host != nil
        else { return nil }

        return SearchResponse(headers: headers, location: location)
    }
}
