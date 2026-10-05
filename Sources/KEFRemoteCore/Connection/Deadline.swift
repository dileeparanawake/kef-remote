import Foundation

/// Run `operation`, but give up after `limit`.
///
/// On time out it calls `onTimeout`, which must make the operation end
/// (cancelling the socket ends a read), then throws
/// ``KEFError/commandTimeout``. A socket read can't see Swift task
/// cancellation, so the group would otherwise wait for it forever.
///
/// - Parameters:
///   - limit: How long to wait.
///   - onTimeout: Ends the operation, for example by cancelling its socket.
///   - operation: The work to time, such as sending a command and reading its reply.
public func withDeadline<T: Sendable>(
    _ limit: Duration,
    onTimeout: @escaping @Sendable () -> Void,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T?.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            return nil
        }
        defer { group.cancelAll() }

        // The first to finish wins: a value, the operation's own error,
        // or nil from the timer.
        if let value = try await group.next() ?? nil {
            return value
        }
        onTimeout()
        throw KEFError.commandTimeout
    }
}
