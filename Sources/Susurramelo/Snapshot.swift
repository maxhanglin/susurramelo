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
        for (offset, sample) in samples.enumerated().reversed() {
            history.record(text: sample.text, duration: sample.duration, appName: sample.app)
            _ = offset
        }

        for page in Page.allCases {
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let view = MainView(history: history, preferences: preferences, onChangeAPIKey: {}, page: page)
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
                let url = dir.appendingPathComponent("\(page.rawValue)-\(name).png")
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
