import Foundation

// MARK: - Batch transcription result

public struct TranscriptWord: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case word
        case spacing
        case audioEvent = "audio_event"
    }

    public let text: String
    public let start: Double
    public let end: Double
    public let kind: Kind
    public let speakerID: String?

    public init(text: String, start: Double, end: Double, kind: Kind, speakerID: String?) {
        self.text = text
        self.start = start
        self.end = end
        self.kind = kind
        self.speakerID = speakerID
    }

    enum CodingKeys: String, CodingKey {
        case text, start, end
        case kind = "type"
        case speakerID = "speaker_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        start = try c.decodeIfPresent(Double.self, forKey: .start) ?? 0
        end = try c.decodeIfPresent(Double.self, forKey: .end) ?? start
        // Unknown token types are treated as audio events so they never leak into the text.
        kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .audioEvent
        speakerID = try c.decodeIfPresent(String.self, forKey: .speakerID)
    }
}

/// Decoded `POST /v1/speech-to-text` (single channel) response.
public struct ScribeBatchResult: Decodable, Sendable {
    public let words: [TranscriptWord]
    public let languageCode: String?
    public let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case words
        case languageCode = "language_code"
        case durationSeconds = "audio_duration_secs"
    }

    public static func decode(_ data: Data) throws -> ScribeBatchResult {
        try JSONDecoder().decode(ScribeBatchResult.self, from: data)
    }
}

// MARK: - Turns

public struct Turn: Codable, Equatable, Sendable {
    public let speakerID: String
    public let start: Double
    public let end: Double
    public let text: String

    public init(speakerID: String, start: Double, end: Double, text: String) {
        self.speakerID = speakerID
        self.start = start
        self.end = end
        self.text = text
    }
}

public enum TranscriptTurns {
    /// Groups consecutive words of the same speaker into turns. Spacing is kept only between words
    /// of the same turn; audio events are dropped.
    public static func build(from words: [TranscriptWord]) -> [Turn] {
        var turns: [Turn] = []
        var speaker: String?
        var start = 0.0
        var end = 0.0
        var text = ""
        var pendingSpacing = ""

        func flush() {
            guard let speaker else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { turns.append(Turn(speakerID: speaker, start: start, end: end, text: trimmed)) }
        }

        for word in words {
            switch word.kind {
            case .audioEvent:
                continue
            case .spacing:
                pendingSpacing += word.text
            case .word:
                let id = word.speakerID ?? "unknown"
                if id != speaker {
                    flush()
                    speaker = id
                    start = word.start
                    text = word.text
                } else {
                    text += pendingSpacing + word.text
                }
                end = word.end
                pendingSpacing = ""
            }
        }
        flush()
        return turns
    }
}

// MARK: - Detecting the local speaker

/// Loudness of the mic (left) and system (right) channels while one speaker was talking.
public struct SpeakerEnergy: Equatable, Sendable {
    public let speakerID: String
    public let mic: Float
    public let system: Float

    public init(speakerID: String, mic: Float, system: Float) {
        self.speakerID = speakerID
        self.mic = mic
        self.system = system
    }
}

public enum MeDetector {
    /// Share of a speaker's energy that must come from the mic to count as the local user.
    public static let threshold: Float = 0.65

    /// The speaker whose speech is mostly on the mic channel, if any.
    public static func meSpeaker(from energies: [SpeakerEnergy]) -> String? {
        var totals: [String: (mic: Float, system: Float)] = [:]
        for energy in energies {
            let current = totals[energy.speakerID] ?? (0, 0)
            totals[energy.speakerID] = (current.mic + energy.mic, current.system + energy.system)
        }
        let ratios = totals.compactMapValues { total -> Float? in
            let sum = total.mic + total.system
            return sum > 0 ? total.mic / sum : nil
        }
        guard let best = ratios.max(by: { $0.value < $1.value }), best.value >= threshold else { return nil }
        return best.key
    }
}

// MARK: - Meeting

public struct Meeting: Codable, Equatable, Identifiable, Sendable {
    public enum Status: Codable, Equatable, Sendable {
        case recording
        case transcribing
        case done
        case failed(String)
    }

    public let id: UUID
    public var title: String
    public let date: Date
    /// Seconds of audio.
    public var duration: TimeInterval = 0
    public var status: Status = .recording
    public var turns: [Turn] = []
    /// Custom names keyed by speaker ID.
    public var speakerNames: [String: String] = [:]
    public var meSpeakerID: String?
    public var languageCode: String?

    public init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }

    /// Speaker IDs in order of first appearance.
    public var speakers: [String] {
        var seen: [String] = []
        for turn in turns where !seen.contains(turn.speakerID) { seen.append(turn.speakerID) }
        return seen
    }

    public func displayName(for speakerID: String) -> String {
        if let name = speakerNames[speakerID], !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if speakerID == meSpeakerID { return "Me" }
        let index = speakers.firstIndex(of: speakerID) ?? speakers.count
        return "Speaker \(index + 1)"
    }

    public var plainText: String {
        turns.map { "\(displayName(for: $0.speakerID)): \($0.text)" }.joined(separator: "\n\n")
    }

    public func markdown(dateText: String) -> String {
        let header = ["# \(title)", "\(dateText) · \(Self.clock(duration))"]
        let body = turns.map { "**\(displayName(for: $0.speakerID))** (\(Self.clock($0.start))): \($0.text)" }
        return (header + body).joined(separator: "\n\n") + "\n"
    }

    /// `m:ss`, or `h:mm:ss` from one hour.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Storage

/// One folder per meeting: `meeting.json` and `audio.m4a`.
public struct MeetingStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func folder(for id: UUID) -> URL { directory.appendingPathComponent(id.uuidString) }
    public func audioURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("audio.m4a") }
    private func metadataURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("meeting.json") }

    public func save(_ meeting: Meeting) throws {
        try FileManager.default.createDirectory(at: folder(for: meeting.id), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(meeting).write(to: metadataURL(for: meeting.id), options: [.atomic, .completeFileProtection])
    }

    /// Newest first. Folders without readable metadata are skipped.
    public func loadAll() throws -> [Meeting] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return folders
            .compactMap { try? decoder.decode(Meeting.self, from: Data(contentsOf: $0.appendingPathComponent("meeting.json"))) }
            .sorted { $0.date > $1.date }
    }

    public func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: folder(for: id))
    }
}
