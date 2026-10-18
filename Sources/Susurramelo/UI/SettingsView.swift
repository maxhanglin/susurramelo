import AppKit
import AVFoundation
import SusurrameloCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var history: HistoryController
    @ObservedObject var preferences: Preferences
    let onChangeAPIKey: () -> Void

    @State private var hasAPIKey = KeychainStore.load() != nil
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var confirmClear = false

    private static let languages: [(code: String, name: String)] = [
        ("", "Automatic"), ("es", "Spanish"), ("en", "English"), ("pt", "Portuguese"),
        ("fr", "French"), ("de", "German"), ("it", "Italian"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings").font(Theme.pageTitle).foregroundStyle(Theme.ink)

                group("Account") {
                    row("ElevenLabs API key", detail: hasAPIKey ? "Saved in your Keychain" : "Not set — dictation is disabled") {
                        Button(hasAPIKey ? "Change…" : "Add key…") {
                            onChangeAPIKey()
                            hasAPIKey = KeychainStore.load() != nil
                        }
                        .buttonStyle(PillButtonStyle(kind: hasAPIKey ? .secondary : .primary))
                    }
                }

                group("Dictation") {
                    row("Language", detail: "Automatic detects the language of each dictation.") {
                        Picker("", selection: $preferences.languageCode) {
                            ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    divider
                    row("Microphone", detail: "Uses the system default input.") { Badge(text: "Upcoming") }
                    divider
                    row("Push to talk", detail: "Hold, speak, release to paste.") { Keycap(text: "Right ⌥") }
                    divider
                    row("Hands-free", detail: "Double-tap to lock; press again to finish.") {
                        HStack(spacing: 4) { Keycap(text: "Right ⌥"); Keycap(text: "Right ⌥") }
                    }
                    divider
                    row("Cancel", detail: "Discards the current dictation.") { Keycap(text: "esc") }
                    divider
                    row("Paste last transcript", detail: nil) {
                        HStack(spacing: 4) { Keycap(text: "⌃"); Keycap(text: "⌘"); Keycap(text: "V") }
                    }
                }

                group("General") {
                    row("Launch at login", detail: nil) {
                        Toggle("", isOn: Binding(
                            get: { preferences.launchAtLogin },
                            set: { preferences.launchAtLogin = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

                group("Data & privacy") {
                    row("Keep history", detail: "Dictations are stored only on this Mac.") {
                        Picker("", selection: $preferences.retention) {
                            Text("Forever").tag(HistoryRetention.keep)
                            Text("24 hours").tag(HistoryRetention.oneDay)
                            Text("Don’t save").tag(HistoryRetention.never)
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: preferences.retention) { history.purge() }
                    }
                    divider
                    row("Clear history", detail: "\(history.history.entries.count) dictations stored") {
                        Button("Clear…") { confirmClear = true }
                            .buttonStyle(PillButtonStyle(kind: .danger))
                            .disabled(history.history.entries.isEmpty)
                    }
                }

                group("Permissions") {
                    permissionRow("Microphone", granted: micStatus == .authorized,
                                  url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                    divider
                    permissionRow("Accessibility", granted: accessibilityTrusted,
                                  url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                }
            }
            .padding(40)
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Delete all dictations from this Mac?", isPresented: $confirmClear) {
            Button("Delete All", role: .destructive) { history.clear() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onAppear(perform: refreshPermissions)
    }

    private func refreshPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityTrusted = AXIsProcessTrusted()
        hasAPIKey = KeychainStore.load() != nil
    }

    private var divider: some View { Divider().overlay(Theme.border) }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            CardContainer { content() }
        }
    }

    private func row<Trailing: View>(_ title: String, detail: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.bodyMedium).foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail).font(Theme.caption).foregroundStyle(Theme.inkTertiary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func permissionRow(_ title: String, granted: Bool, url: String) -> some View {
        row(title, detail: granted ? "Granted" : "Needed for dictation to work") {
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success).font(.system(size: 18))
            } else {
                Button("Open Settings") { NSWorkspace.shared.open(URL(string: url)!) }
                    .buttonStyle(PillButtonStyle(kind: .primary))
            }
        }
    }
}
