import AppKit
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case home, dictionary, insights, notetaker, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .dictionary: "Dictionary"
        case .insights: "Insights"
        case .notetaker: "Notetaker"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .dictionary: "character.book.closed"
        case .insights: "chart.bar.xaxis"
        case .notetaker: "person.2.wave.2"
        case .settings: "gearshape"
        }
    }

    var isUpcoming: Bool { self == .insights }
}

/// Owns the main window. The app is a menu-bar app; while this window is open it also shows in the Dock.
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeRoot: () -> AnyView

    init<V: View>(root: @escaping () -> V) {
        makeRoot = { AnyView(root()) }
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Susurramelo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 560)
        window.backgroundColor = NSColor(Theme.canvas)
        window.contentView = NSHostingView(rootView: makeRoot())
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("SusurrameloMainWindow")
        return window
    }
}

struct MainView: View {
    @ObservedObject var history: HistoryController
    @ObservedObject var preferences: Preferences
    @ObservedObject var dictionary: DictionaryController
    @ObservedObject var notetaker: NotetakerController
    let onChangeAPIKey: () -> Void
    @State var page: Page = .home
    /// Opens a meeting directly (snapshots).
    var openMeeting: UUID?

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Theme.panel)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 24))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 24)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
                .padding(.top, Theme.titlebarHeight)
                .padding([.trailing, .bottom], Theme.panelGap)
        }
        .background(Theme.canvas)
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .home: HomeView(history: history)
        case .dictionary: DictionaryView(dictionary: dictionary)
        case .insights: UpcomingView(page: .insights)
        case .notetaker: NotetakerView(notetaker: notetaker, selectedID: openMeeting)
        case .settings: SettingsView(history: history, preferences: preferences, onChangeAPIKey: onChangeAPIKey)
        }
    }
}

private struct Sidebar: View {
    @Binding var page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                BrandMark(size: 26)
                Text("Susurramelo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)

            ForEach([Page.home, .dictionary, .insights, .notetaker]) { item in
                NavItem(page: item, selection: $page)
            }

            Spacer()

            Divider().overlay(Theme.border).padding(.bottom, 8)
            NavItem(page: .settings, selection: $page)
        }
        .padding(.top, Theme.titlebarHeight)
        .padding([.horizontal, .bottom], 12)
        .frame(width: Theme.sidebarWidth)
    }
}

private struct NavItem: View {
    let page: Page
    @Binding var selection: Page
    @State private var hovering = false

    var body: some View {
        Button { selection = page } label: {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20, height: 20)
                Text(page.title)
                    .font(Theme.bodyMedium)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
                if page.isUpcoming { Badge(text: "Upcoming") }
            }
            .foregroundStyle(Theme.ink)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (selection == page || hovering) ? Theme.fill : .clear,
                in: RoundedRectangle(cornerRadius: Theme.navRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// The app mark drawn in code (gradient tile with a waveform), so it never depends on the bundle icon.
struct BrandMark: View {
    let size: CGFloat
    private let heights: [CGFloat] = [0.3, 0.6, 1, 0.6, 0.3]

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26)
            .fill(Theme.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                HStack(spacing: size * 0.07) {
                    ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                        Capsule().fill(.white).frame(width: size * 0.09, height: size * 0.55 * h)
                    }
                }
            )
    }
}
