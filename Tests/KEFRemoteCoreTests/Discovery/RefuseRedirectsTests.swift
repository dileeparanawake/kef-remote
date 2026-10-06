import Foundation
import Testing
@testable import KEFRemoteCore

/// A device on the network can't send the description fetch on to the
/// internet with a redirect.
struct RefuseRedirectsTests {

    @Test func aRedirectIsNotFollowed() async throws {
        let local = URL(string: "http://192.168.1.80:8080/description.xml")!
        let outside = URL(string: "http://93.184.216.34/description.xml")!
        // Made, never started: nothing goes on the network.
        let task = URLSession.shared.dataTask(with: local)
        let redirect = try #require(HTTPURLResponse(url: local, statusCode: 302, httpVersion: nil, headerFields: ["Location": outside.absoluteString]))

        let next = await RefuseRedirects().urlSession(
            URLSession.shared, task: task, willPerformHTTPRedirection: redirect, newRequest: URLRequest(url: outside)
        )

        #expect(next == nil)
    }
}
