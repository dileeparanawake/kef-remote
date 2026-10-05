import Foundation

extension SpeakerFinder {
    /// Look for the saved speaker again, for when its IP may have changed.
    ///
    /// - Parameter saved: The speaker in config. Its MAC picks which KEF to keep.
    /// - Returns: The speaker config to save (new IP, and MAC and name if they
    ///   were missing), or nil when the speaker was not found.
    public func rediscover(_ saved: AppConfig.SpeakerConfig?) async throws -> AppConfig.SpeakerConfig? {
        guard let found = try await find(savedMAC: saved?.mac) else { return nil }

        let oldIP = saved?.lastKnownIp
        if let oldIP, oldIP != found.ip {
            log.info("Discovery: speaker moved from \(oldIP) to \(found.ip)")
        } else if oldIP == found.ip {
            log.info("Discovery: speaker is still at \(found.ip)")
        }

        var updated = saved ?? AppConfig.SpeakerConfig()
        updated.remember(found)
        return updated
    }
}

extension AppConfig.SpeakerConfig {
    /// Take the IP from discovery. Fill in MAC and name only when missing,
    /// so a MAC the user saved keeps the way they wrote it.
    public mutating func remember(_ found: FoundSpeaker) {
        lastKnownIp = found.ip
        if (mac ?? "").isEmpty, !found.mac.isEmpty { mac = found.mac }
        if (name ?? "").isEmpty { name = found.name }
    }
}

extension KEFError {
    /// True when the speaker could not be reached, so it may have a new IP.
    /// False when it answered with something unexpected.
    public var isConnectionFailure: Bool {
        switch self {
        case .connectionFailed, .notConnected, .speakerUnreachable, .commandTimeout:
            return true
        case .invalidResponse:
            return false
        }
    }
}
