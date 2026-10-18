import Testing
@testable import SusurrameloCore

@Suite struct PushToTalkTests {
    @Test func keyDownStartsRecording() {
        var ptt = PushToTalk(minimumHold: 0.25)
        #expect(ptt.handle(.keyDown(at: 10)) == .startRecording)
        #expect(ptt.isRecording)
    }

    @Test func releaseAfterMinimumHoldCommits() {
        var ptt = PushToTalk(minimumHold: 0.25)
        _ = ptt.handle(.keyDown(at: 10))
        #expect(ptt.handle(.keyUp(at: 11)) == .stopAndCommit)
        #expect(!ptt.isRecording)
    }

    @Test func shortTapCancels() {
        var ptt = PushToTalk(minimumHold: 0.25)
        _ = ptt.handle(.keyDown(at: 10))
        #expect(ptt.handle(.keyUp(at: 10.1)) == .cancel)
        #expect(!ptt.isRecording)
    }

    @Test func repeatedKeyDownWhileRecordingIsIgnored() {
        var ptt = PushToTalk(minimumHold: 0.25)
        _ = ptt.handle(.keyDown(at: 10))
        #expect(ptt.handle(.keyDown(at: 10.5)) == .none)
        #expect(ptt.handle(.keyUp(at: 11)) == .stopAndCommit)
    }

    @Test func keyUpWhileIdleIsIgnored() {
        var ptt = PushToTalk(minimumHold: 0.25)
        #expect(ptt.handle(.keyUp(at: 10)) == .none)
    }
}
