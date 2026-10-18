import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct AudioLevelTests {
    @Test func silenceIsZero() {
        #expect(AudioLevel.normalized(samples: [Float](repeating: 0, count: 160)) == 0)
        #expect(AudioLevel.normalized(samples: []) == 0)
    }

    @Test func fullScaleIsOne() {
        let samples = (0..<160).map { $0 % 2 == 0 ? Float(1) : Float(-1) }
        #expect(AudioLevel.normalized(samples: samples) == 1)
    }

    @Test func quietSpeechMapsToTheMiddleOfTheRange() {
        // -30 dBFS RMS on a -60…0 dB scale → 0.5.
        let amplitude = Float(pow(10.0, -30.0 / 20.0))
        let samples = (0..<160).map { $0 % 2 == 0 ? amplitude : -amplitude }
        let level = AudioLevel.normalized(samples: samples)
        #expect(abs(level - 0.5) < 0.01)
    }

    @Test func levelsBelowTheFloorClampToZero() {
        let amplitude = Float(pow(10.0, -80.0 / 20.0))
        #expect(AudioLevel.normalized(samples: [amplitude, -amplitude]) == 0)
    }

    @Test func historyKeepsTheLastValuesInOrder() {
        var history = LevelHistory(capacity: 3)
        #expect(history.values == [0, 0, 0])
        history.append(0.1)
        history.append(0.2)
        history.append(0.3)
        history.append(0.4)
        #expect(history.values == [0.2, 0.3, 0.4])
    }
}
