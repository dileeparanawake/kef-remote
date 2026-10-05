import Foundation
@testable import KEFRemoteCore

/// Test double for DescriptionFetcher. Maps URLs to description.xml bodies.
final class MockDescriptionFetcher: DescriptionFetcher, @unchecked Sendable {
    struct NotFound: Error {}

    private let lock = NSLock()
    private let bodies: [String: Data]
    private var fetchedURLs: [URL] = []

    init(_ bodies: [String: Data] = [:]) {
        self.bodies = bodies
    }

    var fetched: [URL] { lock.lock(); defer { lock.unlock() }; return fetchedURLs }

    func fetch(_ url: URL) async throws -> Data {
        lock.withLock { fetchedURLs.append(url) }
        guard let body = bodies[url.absoluteString] else { throw NotFound() }
        return body
    }
}
