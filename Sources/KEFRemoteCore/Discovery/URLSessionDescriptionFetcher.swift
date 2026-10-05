import Foundation

/// Fetches description.xml over HTTP with a short timeout.
public struct URLSessionDescriptionFetcher: DescriptionFetcher {
    public struct BadStatus: Error, CustomStringConvertible {
        public let code: Int
        public var description: String { "HTTP \(code)" }
    }

    private let session: URLSession

    public init(timeout: TimeInterval = 2) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        session = URLSession(configuration: configuration)
    }

    public func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw BadStatus(code: http.statusCode)
        }
        return data
    }
}
