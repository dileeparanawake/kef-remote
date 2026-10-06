import Foundation

/// Fetches description.xml over HTTP with a short timeout.
///
/// ``SpeakerFinder`` only asks for a LOCATION on this network
/// (``LocalAddress``). Redirects are refused too, so a device on the
/// network can't send the fetch on to the internet: a redirect comes
/// back as its 3xx status, and the reply is dropped.
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
        let (data, response) = try await session.data(from: url, delegate: RefuseRedirects())
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw BadStatus(code: http.statusCode)
        }
        return data
    }
}

/// Answers every redirect with nil: don't follow it.
final class RefuseRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
