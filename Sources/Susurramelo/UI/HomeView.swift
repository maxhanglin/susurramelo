import AppKit
import SusurrameloCore
import SwiftUI

struct HomeView: View {
    @ObservedObject var history: HistoryController
    @State private var query = ""

    private var entries: [HistoryEntry] { history.history.search(query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                StatsRow(history: history.history)
                historySection
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 32)
            .frame(maxWidth: 1046, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(history.history.totalWords >= 2000 ? "Welcome back" : "Hey there, let’s get you talking")
                .font(Theme.pageTitle)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                Text("Hold").foregroundStyle(Theme.inkTertiary)
                Keycap(text: "Right ⌥")
                Text("to dictate, double-tap for hands-free, and").foregroundStyle(Theme.inkTertiary)
                Keycap(text: "⌃")
                Keycap(text: "⌘")
                Keycap(text: "V")
                Text("pastes your last one.").foregroundStyle(Theme.inkTertiary)
            }
            .font(Theme.body)
        }
    }

    @ViewBuilder private var historySection: some View {
        HStack {
            Text("History")
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            Spacer()
            SearchField(text: $query)
        }

        if history.history.entries.isEmpty {
            EmptyHistory()
        } else if entries.isEmpty {
            Text("No dictations match “\(query)”.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkTertiary)
                .padding(.vertical, 24)
        } else {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(history.history.groupedByDay(entries), id: \.day) { group in
                    Section {
                        CardContainer {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider().overlay(Theme.border) }
                                HistoryRow(entry: entry, onDelete: { history.delete(entry) })
                            }
                        }
                        .padding(.bottom, 8)
                    } header: {
                        SectionLabel(text: Self.dayTitle(group.day))
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel)
                    }
                }
            }
        }
    }

    private static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct StatsRow: View {
    let history: History

    var body: some View {
        HStack(spacing: 28) {
            stat(history.totalWords.formatted(), "words dictated")
            stat(history.entries.count.formatted(), "dictations")
            stat(wordsPerMinute.map { $0.formatted() } ?? "—", "wpm")
        }
    }

    private var wordsPerMinute: Int? {
        let minutes = history.entries.reduce(0) { $0 + $1.duration } / 60
        guard minutes > 0.1 else { return nil }
        return Int((Double(history.totalWords) / minutes).rounded())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value).font(Theme.statNumber).foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.inkTertiary)
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let onDelete: () -> Void
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(Theme.caption)
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 98, alignment: .leading)
                .padding(16)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let app = entry.appName {
                    Text(app).font(Theme.caption).foregroundStyle(Theme.inkTertiary)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                HoverIconButton(systemImage: copied ? "checkmark" : "doc.on.doc", help: "Copy") { copy() }
                HoverIconButton(systemImage: "trash", help: "Delete", action: onDelete)
            }
            .padding(12)
            .opacity(hovering ? 1 : 0)
        }
        .background(hovering ? Theme.panel.opacity(0.6) : .clear)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

private struct EmptyHistory: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.brandGradient)
                .padding(16)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
            Text("No dictations yet")
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            Text("Hold Right Option anywhere, say something, and let go. Your dictations will show up here.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkTertiary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.body)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.iconMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 32)
        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Theme.border, lineWidth: 1))
    }
}
