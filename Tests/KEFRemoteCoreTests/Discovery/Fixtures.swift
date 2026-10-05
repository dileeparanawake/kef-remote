import Foundation

/// Replies and descriptions shaped like the ones seen on a real network.
enum Fixtures {
    static let kefSerial = "A1B2C3D4E5F6"

    static func reply(
        location: String,
        st: String = "urn:schemas-upnp-org:device:MediaRenderer:1",
        server: String = "KnOS/3.2 UPnP/1.0 DMP/3.5"
    ) -> Data {
        let lines: [String] = [
            "HTTP/1.1 200 OK",
            "CACHE-CONTROL: max-age=1800",
            "EXT:",
            "LOCATION: \(location)",
            "SERVER: \(server)",
            "ST: \(st)",
            "USN: uuid:00000000-0000-0000-0000-\(kefSerial)::\(st)",
        ]
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    static func description(
        manufacturer: String = "KEF",
        friendlyName: String = "LSX",
        modelName: String = "SP3994",
        serialNumber: String = kefSerial
    ) -> Data {
        Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <device>
            <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
            <friendlyName>\(friendlyName)</friendlyName>
            <manufacturer>\(manufacturer)</manufacturer>
            <modelName>\(modelName)</modelName>
            <serialNumber>\(serialNumber)</serialNumber>
            <UDN>uuid:00000000-0000-0000-0000-\(serialNumber)</UDN>
          </device>
        </root>
        """.utf8)
    }
}
