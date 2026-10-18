import Testing
@testable import SusurrameloCore

@Suite struct DictationGestureTests {
    private func gesture() -> DictationGesture {
        DictationGesture(minimumHold: 0.25, doubleTapWindow: 0.4)
    }

    // MARK: Hold to talk (existing behavior, S7)

    @Test func keyDownStartsRecording() {
        var g = gesture()
        #expect(g.handle(.keyDown(at: 10)) == .startRecording)
        #expect(g.isActive)
    }

    @Test func releaseAfterMinimumHoldCommits() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        #expect(g.handle(.keyUp(at: 11)) == .stopAndCommit)
        #expect(!g.isActive)
    }

    @Test func repeatedKeyDownWhileHoldingIsIgnored() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        #expect(g.handle(.keyDown(at: 10.5)) == .none)
        #expect(g.handle(.keyUp(at: 11)) == .stopAndCommit)
    }

    @Test func keyUpWhileIdleIsIgnored() {
        var g = gesture()
        #expect(g.handle(.keyUp(at: 10)) == .none)
    }

    // MARK: Single short tap (S7)

    @Test func shortTapWaitsForSecondTapWhileStillRecording() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        #expect(g.handle(.keyUp(at: 10.1)) == .awaitSecondTap(deadline: 10.5))
        #expect(g.isActive)
    }

    @Test func shortTapWithoutSecondPressCancelsAtTimeout() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        #expect(g.handle(.tapTimeout(at: 10.5)) == .cancel)
        #expect(!g.isActive)
    }

    @Test func earlyTapTimeoutIsIgnored() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        #expect(g.handle(.tapTimeout(at: 10.2)) == .none)
        #expect(g.isActive)
    }

    @Test func staleTapTimeoutAfterCommitIsIgnored() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 11))
        #expect(g.handle(.tapTimeout(at: 11.4)) == .none)
    }

    // MARK: Hands-free via double tap (S6)

    @Test func secondPressWithinWindowLocksHandsFree() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        #expect(g.handle(.keyDown(at: 10.3)) == .lockHandsFree)
        #expect(g.isHandsFree)
        // Releasing the locking press keeps recording.
        #expect(g.handle(.keyUp(at: 10.4)) == .none)
        #expect(g.isActive)
        // The lock survives the original tap timeout.
        #expect(g.handle(.tapTimeout(at: 10.5)) == .none)
        #expect(g.isActive)
    }

    @Test func pressingAgainInHandsFreeCommitsAndIgnoresItsRelease() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        _ = g.handle(.keyDown(at: 10.3))
        _ = g.handle(.keyUp(at: 10.4))
        #expect(g.handle(.keyDown(at: 20)) == .stopAndCommit)
        #expect(!g.isActive)
        #expect(g.handle(.keyUp(at: 20.1)) == .none)
        // The next press starts a fresh dictation.
        #expect(g.handle(.keyDown(at: 30)) == .startRecording)
    }

    @Test func secondPressAfterWindowCancels() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        #expect(g.handle(.keyDown(at: 10.6)) == .cancel)
        #expect(!g.isActive)
    }

    // MARK: Esc cancels (S5)

    @Test func escapeCancelsWhileHolding() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        #expect(g.handle(.escape) == .cancel)
        #expect(!g.isActive)
        // The eventual release of the held key does nothing.
        #expect(g.handle(.keyUp(at: 11)) == .none)
    }

    @Test func escapeCancelsWhileAwaitingSecondTap() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        #expect(g.handle(.escape) == .cancel)
        #expect(g.handle(.tapTimeout(at: 10.5)) == .none)
    }

    @Test func escapeCancelsHandsFree() {
        var g = gesture()
        _ = g.handle(.keyDown(at: 10))
        _ = g.handle(.keyUp(at: 10.1))
        _ = g.handle(.keyDown(at: 10.3))
        _ = g.handle(.keyUp(at: 10.4))
        #expect(g.handle(.escape) == .cancel)
        #expect(!g.isActive)
    }

    @Test func escapeWhileIdleDoesNothing() {
        var g = gesture()
        #expect(g.handle(.escape) == .none)
    }
}
