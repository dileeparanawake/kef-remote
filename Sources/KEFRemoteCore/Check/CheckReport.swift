import Foundation

/// How one step of the check went: one printed line.
public struct CheckStepResult: Equatable {
    public enum Verdict: String {
        case pass = "PASS"
        case fail = "FAIL"
        case skip = "SKIP"
    }

    public let name: String
    public let verdict: Verdict
    /// What was expected and read back, or why it failed or was skipped.
    public let detail: String
    /// The step's last write, if it sent one.
    public let sentBytes: Data?
    /// The speaker's reply to the step's last read.
    public let readBytes: Data?

    public init(name: String, verdict: Verdict, detail: String, sentBytes: Data? = nil, readBytes: Data? = nil) {
        self.name = name
        self.verdict = verdict
        self.detail = detail
        self.sentBytes = sentBytes
        self.readBytes = readBytes
    }

    /// `PASS  volume up: expected 42%, read 42% [sent 53 25 81 2A, read 52 25 81 2A 00]`
    public var line: String {
        let text = "\(verdict.rawValue)  \(name): \(detail)"
        guard sentBytes != nil || readBytes != nil else { return text }
        let sent = sentBytes.map { "sent \($0.hexString)" } ?? "sent nothing"
        let read = readBytes.map { "read \($0.hexString)" } ?? "read nothing"
        return "\(text) [\(sent), \(read)]"
    }
}

/// Everything one run of the check found.
public struct CheckReport: Equatable {
    public let steps: [CheckStepResult]
    /// Putting the starting state back. Nil when the starting state
    /// couldn't be read, so nothing was changed.
    public let restore: CheckStepResult?

    public init(steps: [CheckStepResult], restore: CheckStepResult?) {
        self.steps = steps
        self.restore = restore
    }

    /// No step failed, and the starting state is back.
    public var passed: Bool {
        !steps.contains { $0.verdict == .fail } && restore?.verdict != .fail
    }

    /// `Done: 10 passed, 0 failed, 1 skipped. Starting state put back.`
    public var summary: String {
        let count = { (verdict: CheckStepResult.Verdict) in self.steps.filter { $0.verdict == verdict }.count }
        let ending: String
        switch restore?.verdict {
        case nil: ending = "Nothing was changed."
        case .fail: ending = "Putting the starting state back FAILED."
        default: ending = "Starting state put back."
        }
        return "Done: \(count(.pass)) passed, \(count(.fail)) failed, \(count(.skip)) skipped. \(ending)"
    }
}
