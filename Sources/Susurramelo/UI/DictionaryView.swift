import SusurrameloCore
import SwiftUI

struct DictionaryView: View {
    @ObservedObject var dictionary: DictionaryController
    @State private var query = ""
    @State private var showingAdd = false

    private var entries: [DictionaryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return dictionary.dictionary.entries }
        return dictionary.dictionary.entries.filter {
            $0.term.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || ($0.replacing?.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if dictionary.dictionary.entries.isEmpty {
                    emptyState
                } else {
                    HStack {
                        Text("\(dictionary.dictionary.keyterms.count) / \(UserDictionary.maxKeyterms) words sent to transcription")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkTertiary)
                        Spacer()
                        DictionarySearchField(text: $query)
                    }
                    if entries.isEmpty {
                        Text("No words match “\(query)”.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkTertiary)
                    } else {
                        CardContainer {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider().overlay(Theme.border) }
                                DictionaryRow(entry: entry, onDelete: { dictionary.delete(entry) })
                            }
                        }
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingAdd) {
            AddWordSheet(dictionary: dictionary, isPresented: $showingAdd)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dictionary").font(Theme.pageTitle).foregroundStyle(Theme.ink)
                Text("Names, brands and jargon you use. Short words (up to 20 characters) help transcription recognize them — this adds about 20% to transcription cost. Add a misspelling to fix it automatically.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            Spacer()
            Button { showingAdd = true } label: {
                Label("Add word", systemImage: "plus")
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.brandGradient)
                .padding(16)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
            Text("No words yet").font(Theme.sectionTitle).foregroundStyle(Theme.ink)
            Text("Add the names and terms you say often so they come out right every time.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Add your first word") { showingAdd = true }
                .buttonStyle(PillButtonStyle(kind: .primary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let replacing = entry.replacing {
                Text(replacing)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .strikethrough(color: Theme.inkTertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.iconMuted)
            }
            Text(entry.term).font(Theme.bodyMedium).foregroundStyle(Theme.ink)
            if !entry.isSentAsKeyterm {
                Text("Replacement only")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .help("Longer than 20 characters, so it is not sent to transcription.")
            }
            Spacer()
            HoverIconButton(systemImage: "trash", help: "Delete", action: onDelete)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

private struct AddWordSheet: View {
    @ObservedObject var dictionary: DictionaryController
    @Binding var isPresented: Bool
    @State private var term = ""
    @State private var fixesMisspelling = false
    @State private var replacing = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add to dictionary").font(Theme.sectionTitle).foregroundStyle(Theme.ink)

            field("Word or phrase", text: $term, placeholder: "e.g. Susurramelo")
            if term.trimmingCharacters(in: .whitespaces).count > UserDictionary.maxKeytermLength {
                Text("Longer than 20 characters: it will only be used for replacements.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.warning)
            }

            Toggle("Fix a misspelling", isOn: $fixesMisspelling)
                .toggleStyle(.switch)
                .font(Theme.bodyMedium)
            if fixesMisspelling {
                field("When transcribed as", text: $replacing, placeholder: "e.g. Susurrámelo")
            }

            if let error {
                Text(error).font(Theme.caption).foregroundStyle(Theme.danger)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Add") { add() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 420)
        .background(Theme.panel)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.caption).foregroundStyle(Theme.inkTertiary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Theme.border, lineWidth: 1))
        }
    }

    private func add() {
        do {
            try dictionary.add(term: term, replacing: fixesMisspelling ? replacing : nil)
            isPresented = false
        } catch UserDictionary.ValidationError.duplicate {
            error = "That word is already in your dictionary."
        } catch {
            self.error = "Enter a word."
        }
    }
}

private struct DictionarySearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkTertiary)
            TextField("Search", text: $text).textFieldStyle(.plain).font(Theme.body)
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 32)
        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Theme.border, lineWidth: 1))
    }
}
