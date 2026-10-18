import Foundation

public struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    /// The word as it should be written.
    public let term: String
    /// Optional text the transcriber tends to produce instead; it is replaced with `term`.
    public let replacing: String?

    public init(id: UUID = UUID(), term: String, replacing: String? = nil) {
        self.id = id
        self.term = term
        self.replacing = replacing
    }

    /// Scribe only accepts keyterms of up to 20 characters.
    public var isSentAsKeyterm: Bool { term.count <= UserDictionary.maxKeytermLength }
}

/// Personal words: sent to the transcriber as keyterms and used to fix recurring misspellings.
public struct UserDictionary: Equatable, Sendable {
    public static let maxKeyterms = 50
    public static let maxKeytermLength = 20

    public enum ValidationError: Error, Equatable {
        case empty
        case duplicate
    }

    /// Newest first.
    public private(set) var entries: [DictionaryEntry]

    public init(entries: [DictionaryEntry] = []) {
        self.entries = entries
    }

    public mutating func add(term: String, replacing: String? = nil) throws {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacing = replacing?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw ValidationError.empty }
        let exists = entries.contains { $0.term.compare(term, options: [.caseInsensitive]) == .orderedSame }
        guard !exists else { throw ValidationError.duplicate }
        entries.insert(DictionaryEntry(term: term, replacing: replacing?.isEmpty == false ? replacing : nil), at: 0)
    }

    public mutating func delete(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Words sent to the transcriber: the newest eligible ones, at most `maxKeyterms`.
    public var keyterms: [String] {
        Array(entries.filter(\.isSentAsKeyterm).map(\.term).prefix(Self.maxKeyterms))
    }

    /// Replaces every whole-word, case-insensitive occurrence of each entry's `replacing` text with its `term`.
    public func apply(to text: String) -> String {
        entries.reduce(text) { result, entry in
            guard let source = entry.replacing else { return result }
            // Lookarounds instead of \b so terms that start or end with symbols (e.g. "C#") still match.
            let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: source) + "(?![\\p{L}\\p{N}_])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return result }
            let range = NSRange(result.startIndex..., in: result)
            return regex.stringByReplacingMatches(
                in: result, range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.term)
            )
        }
    }

    // MARK: Persistence

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtection])
    }

    public static func load(from url: URL) throws -> UserDictionary {
        guard FileManager.default.fileExists(atPath: url.path) else { return UserDictionary() }
        return UserDictionary(entries: try JSONDecoder().decode([DictionaryEntry].self, from: Data(contentsOf: url)))
    }
}
