import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct MeetingTests {
    // Shape taken from a real Scribe v2 batch response (words and spacing tokens).
    private let response = #"""
    {"language_code":"spa","text":"Hola a todos. Perfecto. Genial.","audio_duration_secs":12.0,"transcription_id":"t1",
     "words":[
      {"text":"Hola","start":0.0,"end":0.24,"type":"word","speaker_id":"speaker_0","logprob":-0.1},
      {"text":" ","start":0.24,"end":0.26,"type":"spacing","speaker_id":"speaker_0","logprob":0},
      {"text":"a","start":0.26,"end":0.32,"type":"word","speaker_id":"speaker_0","logprob":0},
      {"text":" ","start":0.32,"end":0.42,"type":"spacing","speaker_id":"speaker_0","logprob":0},
      {"text":"todos.","start":0.42,"end":0.9,"type":"word","speaker_id":"speaker_0","logprob":0},
      {"text":" ","start":0.9,"end":5.9,"type":"spacing","speaker_id":"speaker_1","logprob":0},
      {"text":"(laughs)","start":5.9,"end":6.1,"type":"audio_event","speaker_id":"speaker_1","logprob":0},
      {"text":"Perfecto.","start":6.1,"end":6.8,"type":"word","speaker_id":"speaker_1","logprob":0},
      {"text":" ","start":6.8,"end":10.0,"type":"spacing","speaker_id":"speaker_0","logprob":0},
      {"text":"Genial.","start":10.0,"end":10.6,"type":"word","speaker_id":"speaker_0","logprob":0}
     ]}
    """#

    @Test func decodesBatchResponseWords() throws {
        let result = try ScribeBatchResult.decode(Data(response.utf8))
        #expect(result.words.count == 10)
        #expect(result.words[0] == TranscriptWord(text: "Hola", start: 0, end: 0.24, kind: .word, speakerID: "speaker_0"))
        #expect(result.durationSeconds == 12)
        #expect(result.languageCode == "spa")
    }

    @Test func groupsWordsIntoSpeakerTurnsSkippingAudioEvents() throws {
        let words = try ScribeBatchResult.decode(Data(response.utf8)).words
        let turns = TranscriptTurns.build(from: words)
        #expect(turns == [
            Turn(speakerID: "speaker_0", start: 0, end: 0.9, text: "Hola a todos."),
            Turn(speakerID: "speaker_1", start: 6.1, end: 6.8, text: "Perfecto."),
            Turn(speakerID: "speaker_0", start: 10.0, end: 10.6, text: "Genial."),
        ])
    }

    @Test func wordsWithoutSpeakerFallBackToUnknown() {
        let turns = TranscriptTurns.build(from: [
            TranscriptWord(text: "Hola", start: 0, end: 1, kind: .word, speakerID: nil),
        ])
        #expect(turns.first?.speakerID == "unknown")
    }

    @Test func detectsMeAsTheSpeakerDominatedByTheMicChannel() {
        let energies: [SpeakerEnergy] = [
            SpeakerEnergy(speakerID: "speaker_0", mic: 9, system: 1),
            SpeakerEnergy(speakerID: "speaker_1", mic: 0.5, system: 8),
            SpeakerEnergy(speakerID: "speaker_0", mic: 7, system: 2),
            SpeakerEnergy(speakerID: "speaker_2", mic: 1, system: 9),
        ]
        #expect(MeDetector.meSpeaker(from: energies) == "speaker_0")
    }

    @Test func noMeWhenNoSpeakerIsClearlyOnTheMic() {
        #expect(MeDetector.meSpeaker(from: [
            SpeakerEnergy(speakerID: "speaker_0", mic: 5, system: 5),
            SpeakerEnergy(speakerID: "speaker_1", mic: 1, system: 9),
        ]) == nil)
        #expect(MeDetector.meSpeaker(from: []) == nil)
    }

    @Test func speakerNamesUseMeCustomNamesAndOrderOfAppearance() {
        var meeting = Meeting(title: "Weekly", date: Date(timeIntervalSince1970: 0))
        meeting.turns = [
            Turn(speakerID: "speaker_3", start: 0, end: 1, text: "a"),
            Turn(speakerID: "speaker_0", start: 1, end: 2, text: "b"),
            Turn(speakerID: "speaker_7", start: 2, end: 3, text: "c"),
        ]
        meeting.meSpeakerID = "speaker_0"
        meeting.speakerNames["speaker_7"] = "Martina"
        #expect(meeting.displayName(for: "speaker_3") == "Speaker 1")
        #expect(meeting.displayName(for: "speaker_0") == "Me")
        #expect(meeting.displayName(for: "speaker_7") == "Martina")
        #expect(meeting.speakers == ["speaker_3", "speaker_0", "speaker_7"])
        // A custom name also overrides "Me".
        meeting.speakerNames["speaker_0"] = "Max"
        #expect(meeting.displayName(for: "speaker_0") == "Max")
    }

    @Test func exportsMarkdownWithTimestampsAndNames() {
        var meeting = Meeting(title: "Launch sync", date: Date(timeIntervalSince1970: 0))
        meeting.duration = 125
        meeting.turns = [
            Turn(speakerID: "speaker_0", start: 0, end: 4, text: "Hola a todos."),
            Turn(speakerID: "speaker_1", start: 65, end: 70, text: "Perfecto."),
        ]
        meeting.meSpeakerID = "speaker_0"
        let markdown = meeting.markdown(dateText: "1 Jan 1970")
        #expect(markdown == """
        # Launch sync

        1 Jan 1970 · 2:05

        **Me** (0:00): Hola a todos.

        **Speaker 2** (1:05): Perfecto.

        """)
    }

    @Test func persistsMeetingsInADirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = MeetingStore(directory: dir)
        var older = Meeting(title: "Older", date: Date(timeIntervalSince1970: 100))
        older.status = .done
        var newer = Meeting(title: "Newer", date: Date(timeIntervalSince1970: 200))
        newer.status = .failed("HTTP 500")
        try store.save(older)
        try store.save(newer)
        let loaded = try store.loadAll()
        #expect(loaded.map(\.title) == ["Newer", "Older"])
        #expect(loaded.first?.status == .failed("HTTP 500"))
        #expect(store.audioURL(for: newer.id).lastPathComponent == "audio.m4a")
        try store.delete(newer.id)
        #expect(try store.loadAll().map(\.title) == ["Older"])
    }
}
