import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct RetryPolicyTests {
    @Test func retriesNetworkRateLimitAndServerErrors() {
        #expect(RetryPolicy.isRetryable(.offline))
        #expect(RetryPolicy.isRetryable(.http(408)))
        #expect(RetryPolicy.isRetryable(.http(429)))
        #expect(RetryPolicy.isRetryable(.http(500)))
        #expect(RetryPolicy.isRetryable(.http(503)))
    }

    @Test func doesNotRetryErrorsThatWillNotFixThemselves() {
        #expect(!RetryPolicy.isRetryable(.http(400)))
        #expect(!RetryPolicy.isRetryable(.http(401)))
        #expect(!RetryPolicy.isRetryable(.http(422)))
        #expect(!RetryPolicy.isRetryable(.other))
    }

    @Test func waitsLongerAfterEachFailedAttemptThenGivesUp() {
        let policy = RetryPolicy()
        #expect(policy.delay(afterAttempt: 1) == 2)
        #expect(policy.delay(afterAttempt: 2) == 10)
        #expect(policy.delay(afterAttempt: 3) == 30)
        #expect(policy.delay(afterAttempt: 4) == nil)
    }

    @Test func onlyOfflineFailuresWaitForTheNetwork() {
        #expect(RetryPolicy.waitsForNetwork(.offline))
        #expect(!RetryPolicy.waitsForNetwork(.http(503)))
        #expect(!RetryPolicy.waitsForNetwork(.http(401)))
    }

    @Test func meetingsSavedBeforeTheRetryFlagStillDecode() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Old","date":"2026-10-18T10:00:00Z","duration":0,"status":{"done":{}},"turns":[],"speakerNames":{}}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meeting = try decoder.decode(Meeting.self, from: Data(json.utf8))
        #expect(meeting.title == "Old")
        #expect(meeting.waitingForNetwork == nil)
    }
}
