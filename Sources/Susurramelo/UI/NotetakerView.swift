import AppKit
import SusurrameloCore
import SwiftUI
import UniformTypeIdentifiers

struct NotetakerView: View {
    @ObservedObject var notetaker: NotetakerController
    @State private var selectedID: UUID?
    @State private var startError: String?

    init(notetaker: NotetakerController, selectedID: UUID? = nil) {
        self.notetaker = notetaker
        _selectedID = State(initialValue: selectedID)
    }

    var body: some View {
        if let id = selectedID, let meeting = notetaker.meetings.first(where: { $0.id == id }) {
            MeetingDetailView(meeting: meeting, notetaker: notetaker, onBack: { selectedID = nil })
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notetaker").font(Theme.pageTitle).foregroundStyle(Theme.ink)
                        Text("Record a meeting from any app. When you stop, the audio is transcribed with who said what.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(maxWidth: 520, alignment: .leading)
                    }
                    Spacer()
                    RecordButton(notetaker: notetaker, startError: $startError)
                }
                if let startError {
                    Text(startError).font(Theme.caption).foregroundStyle(Theme.danger)
                }

                if notetaker.meetings.isEmpty {
                    emptyState
                } else {
                    CardContainer {
                        ForEach(Array(notetaker.meetings.enumerated()), id: \.element.id) { index, meeting in
                            if index > 0 { Divider().overlay(Theme.border) }
                            MeetingRow(meeting: meeting, isRecording: meeting.id == notetaker.recordingID) {
                                if meeting.id != notetaker.recordingID { selectedID = meeting.id }
                            }
                        }
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.brandGradient)
                .padding(16)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
            Text("No meetings yet").font(Theme.sectionTitle).foregroundStyle(Theme.ink)
            Text("Start a recording when your call begins. Your mic and the call audio are captured; nothing is sent until you stop.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// Start / stop button with a live timer while recording.
struct RecordButton: View {
    @ObservedObject var notetaker: NotetakerController
    @Binding var startError: String?

    var body: some View {
        if notetaker.isRecording, let started = notetaker.recordingStartedAt {
            Button { notetaker.stopRecording() } label: {
                HStack(spacing: 8) {
                    Circle().fill(Theme.danger).frame(width: 8, height: 8)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Stop · \(Meeting.clock(context.date.timeIntervalSince(started)))").monospacedDigit()
                    }
                }
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
        } else {
            Button {
                do {
                    try notetaker.startRecording()
                    startError = nil
                } catch {
                    startError = "Could not start recording: \(error.localizedDescription). Check Microphone and System Audio Recording in System Settings → Privacy & Security."
                }
            } label: {
                Label("Record meeting", systemImage: "record.circle")
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let isRecording: Bool
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meeting.title).font(Theme.bodyMedium).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(subtitle).font(Theme.caption).foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                StatusBadge(status: meeting.status, isRecording: isRecording)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.iconMuted)
                    .opacity(isRecording ? 0 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(hovering && !isRecording ? Theme.panel.opacity(0.6) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        var parts = [meeting.date.formatted(date: .abbreviated, time: .shortened)]
        if meeting.duration > 0 { parts.append(Meeting.clock(meeting.duration)) }
        if !meeting.speakers.isEmpty { parts.append("\(meeting.speakers.count) speakers") }
        return parts.joined(separator: " · ")
    }
}

private struct StatusBadge: View {
    let status: Meeting.Status
    let isRecording: Bool

    var body: some View {
        switch status {
        case .done:
            EmptyView()
        case .recording where isRecording:
            label("Recording", color: Theme.danger)
        case .recording, .failed:
            label("Failed", color: Theme.danger)
        case .transcribing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Transcribing").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(color)
    }
}

// MARK: - Detail

private struct MeetingDetailView: View {
    let meeting: Meeting
    @ObservedObject var notetaker: NotetakerController
    let onBack: () -> Void
    @State private var title = ""
    @State private var editingSpeaker: String?
    @State private var speakerName = ""
    @State private var confirmDelete = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: onBack) {
                    Label("All meetings", systemImage: "chevron.left").font(Theme.bodyMedium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkTertiary)

                TextField("Title", text: $title, onCommit: { notetaker.rename(meeting.id, title: title) })
                    .textFieldStyle(.plain)
                    .font(Theme.pageTitle)
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 8) {
                    Text(meta).font(Theme.caption).foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    if meeting.status == .done {
                        Button(copied ? "Copied" : "Copy") { copy() }.buttonStyle(PillButtonStyle(kind: .secondary))
                        Button("Export…") { export() }.buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                    Button("Delete…") { confirmDelete = true }.buttonStyle(PillButtonStyle(kind: .danger))
                }

                content
            }
            .padding(40)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { title = meeting.title }
        .onChange(of: meeting.id) { title = meeting.title }
        .confirmationDialog("Delete this meeting and its audio?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                notetaker.delete(meeting.id)
                onBack()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch meeting.status {
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Transcribing… this usually takes a few seconds per minute of audio.")
                    .font(Theme.body).foregroundStyle(Theme.inkTertiary)
            }
            .padding(.vertical, 24)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Text("Transcription failed").font(Theme.sectionTitle).foregroundStyle(Theme.ink)
                Text(message).font(Theme.caption).foregroundStyle(Theme.inkTertiary).textSelection(.enabled)
                Button("Try again") { notetaker.transcribe(meeting.id) }.buttonStyle(PillButtonStyle(kind: .primary))
            }
        case .recording:
            Text("Recording in progress.").font(Theme.body).foregroundStyle(Theme.inkTertiary)
        case .done:
            speakers
            transcript
        }
    }

    private var speakers: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Speakers")
            HStack(spacing: 8) {
                ForEach(meeting.speakers, id: \.self) { speaker in
                    if editingSpeaker == speaker {
                        TextField("Name", text: $speakerName, onCommit: {
                            notetaker.renameSpeaker(meeting.id, speakerID: speaker, to: speakerName)
                            editingSpeaker = nil
                        })
                        .textFieldStyle(.plain)
                        .font(Theme.bodyMedium)
                        .padding(.horizontal, 10)
                        .frame(width: 160, height: 30)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Theme.border))
                    } else {
                        Button {
                            speakerName = meeting.displayName(for: speaker)
                            editingSpeaker = speaker
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(SpeakerColor.for(speaker, in: meeting)).frame(width: 8, height: 8)
                                Text(meeting.displayName(for: speaker)).font(Theme.bodyMedium)
                                Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(Theme.iconMuted)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Theme.border))
                            .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(.plain)
                        .help("Rename")
                    }
                }
            }
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Transcript")
            if meeting.turns.isEmpty {
                Text("No speech was detected in this recording.").font(Theme.body).foregroundStyle(Theme.inkTertiary)
            } else {
                CardContainer {
                    ForEach(Array(meeting.turns.enumerated()), id: \.offset) { index, turn in
                        if index > 0 { Divider().overlay(Theme.border) }
                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.displayName(for: turn.speakerID))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SpeakerColor.for(turn.speakerID, in: meeting))
                                Text(Meeting.clock(turn.start)).font(Theme.caption).foregroundStyle(Theme.inkTertiary).monospacedDigit()
                            }
                            .frame(width: 120, alignment: .leading)
                            .padding(16)
                            Text(turn.text)
                                .font(Theme.body)
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 16)
                                .padding(.trailing, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var meta: String {
        var parts = [meeting.date.formatted(date: .complete, time: .shortened)]
        if meeting.duration > 0 { parts.append(Meeting.clock(meeting.duration)) }
        return parts.joined(separator: " · ")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(meeting.plainText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = meeting.title.replacingOccurrences(of: "/", with: "-") + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let markdown = meeting.markdown(dateText: meeting.date.formatted(date: .complete, time: .shortened))
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Stable color per speaker, by order of appearance.
enum SpeakerColor {
    private static let palette: [Color] = [
        Color(hex: 0x5B45C9), Color(hex: 0x0E7C86), Color(hex: 0xC2410C),
        Color(hex: 0x15803D), Color(hex: 0xBE185D), Color(hex: 0x1D4ED8),
    ]

    static func `for`(_ speakerID: String, in meeting: Meeting) -> Color {
        if speakerID == meeting.meSpeakerID { return Theme.ink }
        let index = meeting.speakers.firstIndex(of: speakerID) ?? 0
        return palette[index % palette.count]
    }
}
