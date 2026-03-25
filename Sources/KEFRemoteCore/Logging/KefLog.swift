/// Logging contract for all KEF Remote concerns.
///
/// Concerns receive a logger at init - they never construct their own.
/// Production uses AppLogger (triple-output), tests use MockKefLog.
public protocol KefLog: Sendable {
    /// The concern name this logger is associated with.
    var category: String { get }

    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}
