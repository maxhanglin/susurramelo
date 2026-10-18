import Foundation

public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let date: Date
    /// Seconds of recorded audio.
    public let duration: TimeInterval
    /// App that had focus when the text was inserted.
    public let appName: String?

    public init(id: UUID = UUID(), text: String, date: Date, duration: TimeInterval, appName: String?) {
        self.id = id
        self.text = text
        self.date = date
        self.duration = duration
        self.appName = appName
    }

    public var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

public enum HistoryRetention: String, Codable, CaseIterable, Sendable {
    case keep
    case oneDay
    case never
}

/// Local dictation history, newest first.
public struct History: Equatable, Sendable {
    public private(set) var entries: [HistoryEntry] = []
    public let capacity: Int

    public init(capacity: Int = 1000, entries: [HistoryEntry] = []) {
        self.capacity = capacity
        self.entries = Array(entries.prefix(capacity))
    }

    public var last: HistoryEntry? { entries.first }
    public var totalWords: Int { entries.reduce(0) { $0 + $1.wordCount } }

    public mutating func add(_ entry: HistoryEntry, retention: HistoryRetention) {
        guard retention != .never else { return }
        entries.insert(entry, at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
    }

    public mutating func delete(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func clear() {
        entries.removeAll()
    }

    /// Applies the retention policy: `.oneDay` drops entries older than 24 h, `.never` drops everything.
    public mutating func purge(now: Date, retention: HistoryRetention) {
        switch retention {
        case .keep: break
        case .oneDay: entries.removeAll { now.timeIntervalSince($0.date) > 24 * 3600 }
        case .never: entries.removeAll()
        }
    }

    /// Case- and accent-insensitive substring search; a blank query returns everything.
    public func search(_ query: String) -> [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Groups the given entries by calendar day, newest day first, keeping each day's order.
    public func groupedByDay(_ items: [HistoryEntry], calendar: Calendar = .current) -> [(day: Date, entries: [HistoryEntry])] {
        var groups: [(day: Date, entries: [HistoryEntry])] = []
        for entry in items {
            let day = calendar.startOfDay(for: entry.date)
            if let index = groups.firstIndex(where: { $0.day == day }) {
                groups[index].entries.append(entry)
            } else {
                groups.append((day, [entry]))
            }
        }
        return groups.sorted { $0.day > $1.day }
    }

    // MARK: Persistence

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: url, options: [.atomic, .completeFileProtection])
    }

    public static func load(from url: URL, capacity: Int = 1000) throws -> History {
        guard FileManager.default.fileExists(atPath: url.path) else { return History(capacity: capacity) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([HistoryEntry].self, from: Data(contentsOf: url))
        return History(capacity: capacity, entries: entries)
    }
}
