import Foundation

/// A KEF speaker that discovery found.
public struct FoundSpeaker: Equatable, Sendable {
    public let ip: String
    /// The speaker's serial number, which is its MAC with no separators.
    public let mac: String
    public let name: String

    public init(ip: String, mac: String, name: String) {
        self.ip = ip
        self.mac = mac
        self.name = name
    }
}

/// Finds the KEF speaker on the local network with SSDP.
///
/// ```
/// M-SEARCH (sent twice) ─▶ replies
///   ST is MediaRenderer?        no ─▶ drop (a Hue, say)
///   fetch LOCATION description.xml
///   manufacturer is KEF?        no ─▶ drop
///   serial matches saved MAC?   no ─▶ drop
///   (or no MAC saved)          yes ─▶ found
/// ```
///
/// Every step is logged: what was sent, heard, kept and dropped.
public struct SpeakerFinder: Sendable {
    private let makeSocket: @Sendable () throws -> DatagramSocket
    private let fetcher: DescriptionFetcher
    private let log: KEFLog
    private let listenFor: Duration
    private let resendAfter: Duration

    /// - Parameters:
    ///   - listenFor: How long to wait for replies in total.
    ///   - resendAfter: When to send the second M-SEARCH (UDP can drop the first).
    public init(
        makeSocket: @escaping @Sendable () throws -> DatagramSocket,
        fetcher: DescriptionFetcher,
        log: KEFLog,
        listenFor: Duration = .seconds(3),
        resendAfter: Duration = .seconds(1)
    ) {
        self.makeSocket = makeSocket
        self.fetcher = fetcher
        self.log = log
        self.listenFor = listenFor
        self.resendAfter = resendAfter
    }

    /// Search the network for the speaker.
    ///
    /// - Parameter savedMAC: The speaker's MAC from config. With none, the first KEF wins.
    /// - Returns: The speaker, or nil when no matching KEF answered in time.
    /// - Throws: When the socket can't be opened or the search can't be sent.
    public func find(savedMAC: String?) async throws -> FoundSpeaker? {
        let wantedMAC = savedMAC.map(MACAddress.normalised).flatMap { $0.isEmpty ? nil : $0 }
        log.info("Discovery: searching for a KEF speaker (saved MAC: \(wantedMAC ?? "none"))")

        let socket = try makeSocket()
        defer { socket.close() }

        let clock = ContinuousClock()
        let start = clock.now
        let end = start + listenFor
        var searchesSent = 0
        var repliesHeard = 0
        var checkedLocations: Set<URL> = []

        func sendSearch() throws {
            searchesSent += 1
            try socket.send(SSDPSearch.mediaRendererRequest,
                            toHost: SSDPSearch.multicastHost, port: SSDPSearch.multicastPort)
            log.info("Discovery: sent M-SEARCH \(searchesSent) of 2 to \(SSDPSearch.multicastHost):\(SSDPSearch.multicastPort)")
        }

        try sendSearch()
        while true {
            let stop = searchesSent < 2 ? min(end, start + resendAfter) : end
            guard let datagram = try await socket.receive(until: stop) else {
                if searchesSent < 2 && clock.now < end {
                    try sendSearch()
                    continue
                }
                break
            }
            repliesHeard += 1
            if let speaker = await check(datagram, wantedMAC: wantedMAC, checkedLocations: &checkedLocations) {
                return speaker
            }
        }

        log.warning("Discovery: no matching KEF found (\(searchesSent) searches, \(repliesHeard) replies heard)")
        return nil
    }

    /// Decide whether one reply is the speaker. Logs why it is kept or dropped.
    private func check(
        _ datagram: Datagram,
        wantedMAC: String?,
        checkedLocations: inout Set<URL>
    ) async -> FoundSpeaker? {
        let from = datagram.fromHost
        log.debug("Discovery: heard from \(from): \(Self.oneLine(datagram.data))")

        guard let response = SearchResponse.parse(datagram.data) else {
            log.info("Discovery: dropped \(from): not an SSDP reply")
            return nil
        }
        log.info("Discovery: heard \(from) (ST \(response.searchTarget ?? "none"), SERVER \(response.headers["SERVER"] ?? "none"))")

        guard response.isMediaRenderer else {
            log.info("Discovery: dropped \(from): ST is not MediaRenderer")
            return nil
        }
        guard checkedLocations.insert(response.location).inserted else {
            log.debug("Discovery: dropped \(from): already checked \(response.location)")
            return nil
        }

        let description: SpeakerDescription
        do {
            let body = try await fetcher.fetch(response.location)
            guard let parsed = SpeakerDescription.parse(body) else {
                log.warning("Discovery: dropped \(from): \(response.location) is not valid XML")
                return nil
            }
            description = parsed
        } catch {
            log.warning("Discovery: dropped \(from): could not fetch \(response.location): \(error)")
            return nil
        }

        guard description.isKEF else {
            log.info("Discovery: dropped \(from): maker is \(description.manufacturer ?? "unknown"), not KEF")
            return nil
        }
        let serial = MACAddress.normalised(description.serialNumber ?? "")
        if let wantedMAC, serial != wantedMAC {
            log.info("Discovery: dropped \(from): KEF serial \(serial) is not the saved MAC \(wantedMAC)")
            return nil
        }

        let name = description.friendlyName ?? "KEF"
        let ip = response.host ?? from
        log.info("Discovery: kept \(ip): KEF \(name) (\(description.modelName ?? "unknown model")), serial \(serial)")
        return FoundSpeaker(ip: ip, mac: serial, name: name)
    }

    /// A reply on one line, for the debug log.
    private static func oneLine(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return data.hexString }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: " | ")
    }
}
