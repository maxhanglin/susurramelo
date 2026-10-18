import Foundation

/// Push-to-talk state machine: hold to record, release to commit.
/// Taps shorter than `minimumHold` are treated as accidental and cancelled.
public struct PushToTalk: Sendable {
    public enum Input: Equatable, Sendable {
        case keyDown(at: TimeInterval)
        case keyUp(at: TimeInterval)
    }

    public enum Action: Equatable, Sendable {
        case none
        case startRecording
        case stopAndCommit
        case cancel
    }

    public let minimumHold: TimeInterval
    private var pressedAt: TimeInterval?

    public init(minimumHold: TimeInterval = 0.25) {
        self.minimumHold = minimumHold
    }

    public var isRecording: Bool { pressedAt != nil }

    public mutating func handle(_ input: Input) -> Action {
        switch input {
        case let .keyDown(time):
            guard pressedAt == nil else { return .none }
            pressedAt = time
            return .startRecording
        case let .keyUp(time):
            guard let start = pressedAt else { return .none }
            pressedAt = nil
            return time - start >= minimumHold ? .stopAndCommit : .cancel
        }
    }
}
