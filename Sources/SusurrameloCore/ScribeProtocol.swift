import Foundation

/// Wire format for ElevenLabs Scribe v2 Realtime speech-to-text over WebSocket.
/// Field names follow the official elevenlabs-js SDK (`src/wrapper/realtime/connection.ts`).
public enum ScribeProtocol {
    public static let modelID = "scribe_v2_realtime"
    public static let apiKeyHeader = "xi-api-key"

    public enum Event: Equatable, Sendable {
        case sessionStarted(sessionID: String)
        case partialTranscript(String)
        case committedTranscript(String)
        case serverError(type: String, message: String?)
        /// A valid message this client does not act on (e.g. `final_transcript`).
        case ignored(type: String)
        case undecodable
    }

    /// Message types the server uses to report failures.
    static let errorTypes: Set<String> = [
        "error", "auth_error", "quota_exceeded", "commit_throttled", "transcriber_error",
        "unaccepted_terms", "rate_limited", "input_error", "invalid_request",
        "queue_overflow", "resource_exhausted", "session_time_limit_exceeded",
        "chunk_size_exceeded", "insufficient_audio_activity",
    ]

    public static func realtimeURL(languageCode: String?) -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.elevenlabs.io"
        components.path = "/v1/speech-to-text/realtime"
        var items = [
            URLQueryItem(name: "model_id", value: modelID),
            URLQueryItem(name: "audio_format", value: "pcm_\(PCM.sampleRate)"),
            URLQueryItem(name: "commit_strategy", value: "manual"),
        ]
        if let languageCode, !languageCode.isEmpty {
            items.append(URLQueryItem(name: "language_code", value: languageCode))
        }
        components.queryItems = items
        return components.url!
    }

    public static func audioChunkMessage(_ audio: Data, commit: Bool, sampleRate: Int) throws -> String {
        let payload = AudioChunk(audioBase64: audio.base64EncodedString(), commit: commit, sampleRate: sampleRate)
        let data = try JSONEncoder().encode(payload)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decodeEvent(_ text: String) -> Event {
        guard let message = try? JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8)) else {
            return .undecodable
        }
        switch message.messageType {
        case "session_started":
            return .sessionStarted(sessionID: message.sessionID ?? "")
        case "partial_transcript":
            return .partialTranscript(message.text ?? "")
        case "committed_transcript":
            return .committedTranscript(message.text ?? "")
        case let type where errorTypes.contains(type):
            return .serverError(type: type, message: message.error ?? message.message)
        default:
            return .ignored(type: message.messageType)
        }
    }

    private struct AudioChunk: Encodable {
        let messageType = "input_audio_chunk"
        let audioBase64: String
        let commit: Bool
        let sampleRate: Int

        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
            case audioBase64 = "audio_base_64"
            case commit
            case sampleRate = "sample_rate"
        }
    }

    private struct ServerMessage: Decodable {
        let messageType: String
        let sessionID: String?
        let text: String?
        let error: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
            case sessionID = "session_id"
            case text, error, message
        }
    }
}
