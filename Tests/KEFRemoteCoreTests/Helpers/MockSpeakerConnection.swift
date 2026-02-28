import Foundation
@testable import KEFRemoteCore

/// Test double for SpeakerConnection. Queue up responses, inspect sent commands.
final class MockSpeakerConnection: SpeakerConnection {
    /// Responses to return, in order. Each `send()` call pops the first one.
    var responses: [Data] = []

    /// Every command sent via `send()` is recorded here.
    private(set) var sentCommands: [Data] = []

    /// If set, `send()` throws this error instead of returning a response.
    var errorToThrow: KEFError?

    func send(_ data: Data) async throws -> Data {
        sentCommands.append(data)
        if let error = errorToThrow {
            throw error
        }
        guard !responses.isEmpty else {
            throw KEFError.invalidResponse
        }
        return responses.removeFirst()
    }
}
