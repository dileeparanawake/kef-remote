/// Whether a host is an IPv4 address on this network, which is the only
/// place discovery fetches a speaker's description.xml from.
///
/// Any device can answer the search and name any LOCATION. Fetching only
/// from a local address means the app never reaches the internet, by
/// construction rather than by trust.
///
/// ```
/// 10.0.0.0/8       private (RFC 1918)
/// 172.16.0.0/12    private (RFC 1918)
/// 192.168.0.0/16   private (RFC 1918)
/// 169.254.0.0/16   link-local
/// 127.0.0.0/8      loopback
/// anything else    not local, names too: DNS could point anywhere
/// ```
public enum LocalAddress {
    public static func isLocal(_ host: String) -> Bool {
        guard let octets = ipv4Octets(host) else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        default: return false
        }
    }

    /// The four numbers of a dotted IPv4 address, or nil for anything else.
    private static func ipv4Octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let octets = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isASCIIDigit) else { return nil }
            return Int(part).flatMap { $0 <= 255 ? $0 : nil }
        }
        return octets.count == 4 ? octets : nil
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
