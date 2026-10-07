import Foundation

extension SpeakerFinder {
    /// Look for the saved speaker, and search again after a miss when the
    /// app started the run by itself (``SearchAgain``).
    ///
    /// - Parameters:
    ///   - saved: The speaker in config. Its MAC picks which KEF to keep.
    ///   - trigger: What started the run.
    ///   - pause: Waits between searches; tests pass one that returns at once.
    /// - Returns: The speaker config to save, or nil when no search found it.
    public func rediscover(
        _ saved: AppConfig.SpeakerConfig?,
        trigger: DiscoveryTrigger,
        pause: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async throws -> AppConfig.SpeakerConfig? {
        let retries = SearchAgain.times(after: trigger)
        var retry = 0
        while true {
            if let updated = try await rediscover(saved) { return updated }
            guard retry < retries else { return nil }
            retry += 1
            log.info("Discovery: no KEF found (\(trigger)); searching again in \(SearchAgain.pause) (\(retry) of \(retries))")
            try await pause(SearchAgain.pause)
        }
    }

    /// Look for the saved speaker again, for when its IP may have changed.
    ///
    /// - Parameter saved: The speaker in config. Its MAC picks which KEF to keep.
    /// - Returns: The speaker config to save (new IP, and MAC, name and
    ///   model if they were missing), or nil when the speaker was not found.
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
    /// Take the IP from discovery. Fill in MAC, name and model only when
    /// missing, so a MAC the user saved keeps the way they wrote it.
    public mutating func remember(_ found: FoundSpeaker) {
        lastKnownIp = found.ip
        if (mac ?? "").isEmpty, !found.mac.isEmpty { mac = found.mac }
        if (name ?? "").isEmpty { name = found.name }
        if (model ?? "").isEmpty { model = found.model }
    }
}
