import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct EnergyTrackTests {
    @Test func appendsOneValuePerWindowFromStreamedSamples() {
        var track = EnergyTrack(windowSamples: 4)
        track.append(samples: [1, 1, 1])
        #expect(track.values.isEmpty)
        track.append(samples: [1, 0, 0, 0, 0, 2, 2])
        // Windows: [1,1,1,1] → 1, [0,0,0,0] → 0; [2,2] is still pending.
        #expect(track.values == [1, 0])
        track.finish()
        #expect(track.values == [1, 0, 2])
    }

    @Test func sumsEnergyOverATimeRange() {
        let track = EnergyTrack(windowSamples: 1600, sampleRate: 16000, values: [1, 2, 3, 4, 5])
        // Windows are 0.1 s; 0.1…0.3 s covers windows 1 and 2.
        #expect(track.energy(from: 0.1, to: 0.3) == 5)
        #expect(track.energy(from: 0.35, to: 10) == 9)
        #expect(track.energy(from: 3, to: 4) == 0)
    }

    @Test func buildsSpeakerEnergiesForEachTurn() {
        let mic = EnergyTrack(windowSamples: 1600, sampleRate: 16000, values: [9, 9, 0, 0])
        let system = EnergyTrack(windowSamples: 1600, sampleRate: 16000, values: [1, 1, 8, 8])
        let turns = [
            Turn(speakerID: "speaker_0", start: 0, end: 0.2, text: "a"),
            Turn(speakerID: "speaker_1", start: 0.2, end: 0.4, text: "b"),
        ]
        let energies = EnergyTrack.speakerEnergies(turns: turns, mic: mic, system: system)
        #expect(energies == [
            SpeakerEnergy(speakerID: "speaker_0", mic: 18, system: 2),
            SpeakerEnergy(speakerID: "speaker_1", mic: 0, system: 16),
        ])
        #expect(MeDetector.meSpeaker(from: energies) == "speaker_0")
    }

    @Test func roundTripsThroughCodable() throws {
        let track = EnergyTrack(windowSamples: 1600, sampleRate: 16000, values: [0.5, 0.25])
        let data = try JSONEncoder().encode(track)
        #expect(try JSONDecoder().decode(EnergyTrack.self, from: data) == track)
    }
}
