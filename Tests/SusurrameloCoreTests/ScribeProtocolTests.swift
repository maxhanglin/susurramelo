import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct ScribeProtocolTests {
    private func query(_ url: URL) -> [String: String?] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
    }

    @Test func realtimeURLUsesScribeV2ManualCommitAndPCM16k() throws {
        let url = ScribeProtocol.realtimeURL(languageCode: nil)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "wss")
        #expect(components.host == "api.elevenlabs.io")
        #expect(components.path == "/v1/speech-to-text/realtime")
        let query = query(url)
        #expect(query["model_id"] == "scribe_v2_realtime")
        #expect(query["audio_format"] == "pcm_16000")
        #expect(query["commit_strategy"] == "manual")
        #expect(query["language_code"] == nil)
    }

    @Test func realtimeURLIncludesLanguageCodeWhenGiven() {
        #expect(query(ScribeProtocol.realtimeURL(languageCode: "es"))["language_code"] == "es")
    }

    @Test func encodesAudioChunkWithSnakeCaseFields() throws {
        let json = try ScribeProtocol.audioChunkMessage(Data([0x01, 0x02, 0x03]), commit: true, sampleRate: 16000)
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["message_type"] as? String == "input_audio_chunk")
        #expect(object["audio_base_64"] as? String == "AQID")
        #expect(object["commit"] as? Bool == true)
        #expect(object["sample_rate"] as? Int == 16000)
        #expect(object.count == 4)
    }

    @Test func decodesSessionStarted() {
        let event = ScribeProtocol.decodeEvent(#"{"message_type":"session_started","session_id":"abc","config":{}}"#)
        #expect(event == .sessionStarted(sessionID: "abc"))
    }

    @Test func decodesPartialAndCommittedTranscripts() {
        #expect(ScribeProtocol.decodeEvent(#"{"message_type":"partial_transcript","text":"hola"}"#) == .partialTranscript("hola"))
        #expect(ScribeProtocol.decodeEvent(#"{"message_type":"committed_transcript","text":"Hola mundo."}"#) == .committedTranscript("Hola mundo."))
    }

    @Test func decodesServerErrorsWithMessage() {
        #expect(
            ScribeProtocol.decodeEvent(#"{"message_type":"auth_error","error":"Invalid API key"}"#)
                == .serverError(type: "auth_error", message: "Invalid API key")
        )
        #expect(
            ScribeProtocol.decodeEvent(#"{"message_type":"unaccepted_terms","error":"Accept the terms"}"#)
                == .serverError(type: "unaccepted_terms", message: "Accept the terms")
        )
        #expect(
            ScribeProtocol.decodeEvent(#"{"message_type":"insufficient_audio_activity"}"#)
                == .serverError(type: "insufficient_audio_activity", message: nil)
        )
    }

    @Test func unknownMessageTypesAreReportedNotDropped() {
        #expect(ScribeProtocol.decodeEvent(#"{"message_type":"final_transcript","text":"x"}"#) == .ignored(type: "final_transcript"))
    }

    @Test func malformedJSONIsReportedAsUndecodable() {
        #expect(ScribeProtocol.decodeEvent("not json") == .undecodable)
    }
}
