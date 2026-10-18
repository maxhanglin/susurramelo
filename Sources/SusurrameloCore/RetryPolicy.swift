import Foundation

/// Why an upload to the transcription service failed.
public enum UploadFailure: Equatable, Sendable {
    /// No connection, DNS failure, timeout or a dropped connection.
    case offline
    case http(Int)
    case other
}

/// When to retry a failed meeting upload, and how long to wait between attempts.
public struct RetryPolicy: Sendable {
    /// Seconds to wait after the 1st, 2nd, 3rd… failed attempt; no more retries afterwards.
    public let delays: [TimeInterval]

    public init(delays: [TimeInterval] = [2, 10, 30]) {
        self.delays = delays
    }

    public func delay(afterAttempt attempt: Int) -> TimeInterval? {
        guard attempt >= 1, attempt <= delays.count else { return nil }
        return delays[attempt - 1]
    }

    /// Errors that can fix themselves: network trouble, rate limiting and server errors.
    public static func isRetryable(_ failure: UploadFailure) -> Bool {
        switch failure {
        case .offline: true
        case let .http(status): status == 408 || status == 429 || (500...599).contains(status)
        case .other: false
        }
    }

    /// Offline failures are retried again automatically once the network comes back.
    public static func waitsForNetwork(_ failure: UploadFailure) -> Bool {
        failure == .offline
    }
}
