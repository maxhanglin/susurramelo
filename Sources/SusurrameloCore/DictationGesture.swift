import Foundation

/// Interprets presses of the dictation key:
/// - hold for at least `minimumHold`, then release → commit;
/// - quick tap + second press within `doubleTapWindow` → hands-free lock; press again to commit;
/// - quick tap with no second press → cancel when the tap times out;
/// - Esc → cancel at any active point.
/// Recording starts on the first key-down so no speech is lost while the gesture is decided.
public struct DictationGesture: Sendable {
    public enum Input: Equatable, Sendable {
        case keyDown(at: TimeInterval)
        case keyUp(at: TimeInterval)
        case tapTimeout(at: TimeInterval)
        case escape
    }

    public enum Action: Equatable, Sendable {
        case none
        case startRecording
        /// The caller must deliver `.tapTimeout` at (or after) `deadline`.
        case awaitSecondTap(deadline: TimeInterval)
        case lockHandsFree
        case stopAndCommit
        case cancel
    }

    private enum Phase: Equatable, Sendable {
        case idle
        case holding(since: TimeInterval)
        case awaitingSecondTap(releasedAt: TimeInterval)
        /// Hands-free; `lockKeyDown` while the press that locked it is still held.
        case handsFree(lockKeyDown: Bool)
        /// The key is still down after a commit or cancel; its release must be ignored.
        case waitingForRelease
    }

    public let minimumHold: TimeInterval
    public let doubleTapWindow: TimeInterval
    private var phase: Phase = .idle

    public init(minimumHold: TimeInterval = 0.25, doubleTapWindow: TimeInterval = 0.4) {
        self.minimumHold = minimumHold
        self.doubleTapWindow = doubleTapWindow
    }

    /// True while audio should be captured.
    public var isActive: Bool {
        switch phase {
        case .holding, .awaitingSecondTap, .handsFree: true
        case .idle, .waitingForRelease: false
        }
    }

    public var isHandsFree: Bool {
        if case .handsFree = phase { return true }
        return false
    }

    public mutating func handle(_ input: Input) -> Action {
        switch (phase, input) {
        case let (.idle, .keyDown(time)):
            phase = .holding(since: time)
            return .startRecording

        case let (.holding(since), .keyUp(time)):
            if time - since >= minimumHold {
                phase = .idle
                return .stopAndCommit
            }
            phase = .awaitingSecondTap(releasedAt: time)
            return .awaitSecondTap(deadline: time + doubleTapWindow)

        case let (.awaitingSecondTap(releasedAt), .keyDown(time)):
            if time - releasedAt <= doubleTapWindow {
                phase = .handsFree(lockKeyDown: true)
                return .lockHandsFree
            }
            phase = .waitingForRelease
            return .cancel

        case let (.awaitingSecondTap(releasedAt), .tapTimeout(time)):
            guard time - releasedAt >= doubleTapWindow else { return .none }
            phase = .idle
            return .cancel

        case (.handsFree(lockKeyDown: true), .keyUp):
            phase = .handsFree(lockKeyDown: false)
            return .none

        case (.handsFree(lockKeyDown: false), .keyDown):
            phase = .waitingForRelease
            return .stopAndCommit

        case (.waitingForRelease, .keyUp):
            phase = .idle
            return .none

        case (.holding, .escape), (.handsFree(lockKeyDown: true), .escape):
            phase = .waitingForRelease
            return .cancel

        case (.awaitingSecondTap, .escape), (.handsFree(lockKeyDown: false), .escape):
            phase = .idle
            return .cancel

        default:
            return .none
        }
    }
}
