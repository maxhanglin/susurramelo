import AppKit
import ServiceManagement
import SusurrameloCore

/// User preferences persisted in UserDefaults.
final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    /// Empty string means automatic language detection.
    @Published var languageCode: String {
        didSet { defaults.set(languageCode, forKey: "languageCode") }
    }

    @Published var retention: HistoryRetention {
        didSet { defaults.set(retention.rawValue, forKey: "historyRetention") }
    }

    init() {
        languageCode = defaults.string(forKey: "languageCode") ?? ""
        retention = defaults.string(forKey: "historyRetention").flatMap(HistoryRetention.init(rawValue:)) ?? .keep
    }

    /// Launch at login is owned by the system (System Settings → General → Login Items).
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                Log.dictation.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            }
            objectWillChange.send()
        }
    }
}

/// History kept in memory and mirrored to Application Support.
final class HistoryController: ObservableObject {
    @Published private(set) var history: History
    private let url: URL
    private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = support.appendingPathComponent("Susurramelo/history.json")
        do {
            history = try History.load(from: url)
        } catch {
            Log.dictation.error("Could not load history: \(error.localizedDescription, privacy: .public)")
            history = History()
        }
        purge()
    }

    func record(text: String, duration: TimeInterval, appName: String?) {
        history.add(HistoryEntry(text: text, date: Date(), duration: duration, appName: appName), retention: preferences.retention)
        save()
    }

    func delete(_ entry: HistoryEntry) {
        history.delete(id: entry.id)
        save()
    }

    func clear() {
        history.clear()
        save()
    }

    /// Applies the current retention policy (also call after changing it).
    func purge() {
        let before = history
        history.purge(now: Date(), retention: preferences.retention)
        if history != before { save() }
    }

    private func save() {
        do {
            try history.save(to: url)
        } catch {
            Log.dictation.error("Could not save history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
