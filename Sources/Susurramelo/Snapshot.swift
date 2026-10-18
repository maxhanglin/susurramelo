import AppKit
import SusurrameloCore
import SwiftUI

/// `Susurramelo --snapshot <dir>` renders each main-window page in light and dark mode to PNG,
/// using sample history in a temporary file (the real history is not read or modified).
enum Snapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[index + 1])
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("susurramelo-snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let preferences = Preferences()
        let history = HistoryController(preferences: preferences, url: tmp)
        for sample in samples.reversed() {
            history.record(text: sample.text, duration: sample.duration, appName: sample.app)
        }
        let dictTmp = tmp.deletingPathExtension().appendingPathExtension("dict.json")
        defer { try? FileManager.default.removeItem(at: dictTmp) }
        let dictionary = DictionaryController(url: dictTmp)
        try? dictionary.add(term: "ElevenLabs", replacing: nil)
        try? dictionary.add(term: "Figma", replacing: nil)
        try? dictionary.add(term: "Susurramelo", replacing: "Susurrámelo")
        let meetingsDir = tmp.deletingPathExtension().appendingPathExtension("meetings")
        defer { try? FileManager.default.removeItem(at: meetingsDir) }
        let store = MeetingStore(directory: meetingsDir)
        var sync = Meeting(title: "Launch sync", date: Date().addingTimeInterval(-3600))
        sync.status = .done
        sync.duration = 1712
        sync.meSpeakerID = "speaker_0"
        sync.speakerNames["speaker_2"] = "Martina"
        sync.turns = [
            Turn(speakerID: "speaker_0", start: 0, end: 5, text: "Thanks for joining. Let’s review where the launch stands."),
            Turn(speakerID: "speaker_1", start: 6, end: 11, text: "Backend is done with the migration and load tests look good."),
            Turn(speakerID: "speaker_2", start: 12, end: 16, text: "Design still owes two onboarding screens; we’ll deliver them Wednesday."),
            Turn(speakerID: "speaker_0", start: 17, end: 21, text: "Great, then we lock the release for the following Monday."),
        ]
        try? store.save(sync)
        var failed = Meeting(title: "Client call", date: Date().addingTimeInterval(-86400))
        failed.status = .failed("Transcription failed (HTTP 503)")
        try? store.save(failed)
        let notetaker = NotetakerController(preferences: preferences, dictionary: dictionary, directory: meetingsDir)

        let renders: [(String, Page, UUID?)] = Page.allCases.map { ($0.rawValue, $0, nil) } + [("meeting", .notetaker, sync.id)]
        for (label, page, meetingID) in renders {
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let view = MainView(history: history, preferences: preferences, dictionary: dictionary, notetaker: notetaker, onChangeAPIKey: {}, page: page, openMeeting: meetingID)
                    .frame(width: 1080, height: 720)
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(x: 0, y: 0, width: 1080, height: 720)
                host.appearance = NSAppearance(named: appearance)
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = host
                window.appearance = NSAppearance(named: appearance)
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let url = dir.appendingPathComponent("\(label)-\(name).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
                print("Wrote \(url.path)")
            }
        }
        exit(0)
    }

    private static let samples: [(text: String, duration: TimeInterval, app: String?)] = [
        ("Can we move the design review to Thursday at three? I want to include the new onboarding screens.", 8, "Slack"),
        ("Remind me to send the invoice to the client before Friday.", 4, "Notes"),
        ("Hola Martina, te paso el resumen de la reunión de hoy: definimos el alcance del MVP y la fecha de entrega.", 9, "Mail"),
        ("Refactor the history store so it purges on launch.", 4, "Cursor"),
    ]
}
