import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct HistoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ text: String, at date: Date, app: String? = nil) -> HistoryEntry {
        HistoryEntry(text: text, date: date, duration: 3, appName: app)
    }

    @Test func addsNewestFirstAndExposesLast() {
        var history = History()
        history.add(entry("first", at: t0), retention: .keep)
        history.add(entry("second", at: t0.addingTimeInterval(60)), retention: .keep)
        #expect(history.entries.map(\.text) == ["second", "first"])
        #expect(history.last?.text == "second")
    }

    @Test func neverRetentionStoresNothing() {
        var history = History()
        history.add(entry("secret", at: t0), retention: .never)
        #expect(history.entries.isEmpty)
        #expect(history.last == nil)
    }

    @Test func capDropsOldestEntries() {
        var history = History(capacity: 2)
        for i in 0..<3 { history.add(entry("e\(i)", at: t0.addingTimeInterval(Double(i))), retention: .keep) }
        #expect(history.entries.map(\.text) == ["e2", "e1"])
    }

    @Test func oneDayRetentionPurgesEntriesOlderThan24Hours() {
        var history = History()
        history.add(entry("old", at: t0), retention: .keep)
        history.add(entry("recent", at: t0.addingTimeInterval(23 * 3600)), retention: .keep)
        history.purge(now: t0.addingTimeInterval(24 * 3600 + 1), retention: .oneDay)
        #expect(history.entries.map(\.text) == ["recent"])
    }

    @Test func purgeWithNeverClearsAndWithKeepDoesNothing() {
        var history = History()
        history.add(entry("a", at: t0), retention: .keep)
        history.purge(now: t0.addingTimeInterval(365 * 86400), retention: .keep)
        #expect(history.entries.count == 1)
        history.purge(now: t0, retention: .never)
        #expect(history.entries.isEmpty)
    }

    @Test func deleteAndClear() {
        var history = History()
        let a = entry("a", at: t0)
        history.add(a, retention: .keep)
        history.add(entry("b", at: t0), retention: .keep)
        history.delete(id: a.id)
        #expect(history.entries.map(\.text) == ["b"])
        history.clear()
        #expect(history.entries.isEmpty)
    }

    @Test func searchIgnoresCaseAndAccents() {
        var history = History()
        history.add(entry("Reunión con Ana", at: t0), retention: .keep)
        history.add(entry("Comprar pan", at: t0), retention: .keep)
        #expect(history.search("reunion").map(\.text) == ["Reunión con Ana"])
        #expect(history.search("  ").count == 2)
    }

    @Test func wordCountAndStats() {
        var history = History()
        history.add(entry("hola  mundo\nde nuevo", at: t0), retention: .keep)
        history.add(entry("uno", at: t0), retention: .keep)
        #expect(history.entries.last?.wordCount == 4)
        #expect(history.totalWords == 5)
        #expect(history.entries.count == 2)
    }

    @Test func groupsByCalendarDayNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var history = History()
        let day1 = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 9))!
        let day2 = calendar.date(from: DateComponents(year: 2027, month: 3, day: 2, hour: 9))!
        history.add(entry("d1 morning", at: day1), retention: .keep)
        history.add(entry("d1 evening", at: day1.addingTimeInterval(10 * 3600)), retention: .keep)
        history.add(entry("d2", at: day2), retention: .keep)
        let groups = history.groupedByDay(history.entries, calendar: calendar)
        #expect(groups.map(\.entries.count) == [1, 2])
        #expect(groups.first?.day == calendar.startOfDay(for: day2))
        #expect(groups.last?.entries.map(\.text) == ["d1 evening", "d1 morning"])
    }

    @Test func persistsAndLoadsFromDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("history.json")
        var history = History()
        history.add(entry("persist me", at: t0, app: "Notes"), retention: .keep)
        try history.save(to: url)
        let loaded = try History.load(from: url)
        #expect(loaded.entries == history.entries)
    }

    @Test func loadingAMissingFileGivesEmptyHistory() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        #expect(try History.load(from: url).entries.isEmpty)
    }
}
