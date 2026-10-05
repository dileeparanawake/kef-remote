import Foundation

/// The SSDP search the app sends to find KEF speakers.
///
/// KEF speakers answer as UPnP MediaRenderers. Other devices (a Hue
/// bridge, for one) also answer, but with a different `ST`.
public enum SSDPSearch {
    /// Where SSDP searches go.
    public static let multicastHost = "239.255.255.250"
    public static let multicastPort: UInt16 = 1900

    /// The search target that KEF speakers answer to.
    public static let mediaRenderer = "urn:schemas-upnp-org:device:MediaRenderer:1"

    /// The M-SEARCH message. MX 2 asks devices to answer within 2 seconds.
    public static let mediaRendererRequest: Data = {
        let lines: [String] = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastHost):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: \(mediaRenderer)",
        ]
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }()
}
