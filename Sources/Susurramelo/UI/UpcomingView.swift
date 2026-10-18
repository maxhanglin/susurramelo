import SwiftUI

/// Placeholder for features that are planned but not built yet.
struct UpcomingView: View {
    let page: Page

    private var summary: String {
        switch page {
        case .insights:
            "See how you talk: words dictated, speaking speed, streaks and the apps you dictate into most."
        case .notetaker:
            "Record meetings with your mic and system audio, get a live transcript, and a summary with who said what."
        default: ""
        }
    }

    private var highlights: [(icon: String, text: String)] {
        switch page {
        case .insights:
            [("textformat.123", "Total words and words per minute over time"),
             ("flame", "Daily and weekly streaks"),
             ("square.grid.3x3", "Activity heatmap"),
             ("app.badge", "Your most-dictated apps")]
        case .notetaker:
            [("waveform.badge.mic", "Live transcript while the meeting happens"),
             ("person.2", "Speaker separation after the meeting"),
             ("doc.text", "Summary, action items and searchable notes"),
             ("calendar", "Start from your calendar events")]
        default: []
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Text(page.title).font(Theme.pageTitle).foregroundStyle(Theme.ink)
                    Badge(text: "Upcoming")
                }
                Text(summary)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: 560, alignment: .leading)

                CardContainer {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider().overlay(Theme.border) }
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.brandGradient)
                                .frame(width: 32, height: 32)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                            Text(item.text).font(Theme.body).foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                .frame(maxWidth: 640)
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
