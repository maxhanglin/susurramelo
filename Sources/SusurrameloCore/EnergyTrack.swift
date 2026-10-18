import Foundation

/// Loudness of one audio channel as one RMS value per fixed window (100 ms at 16 kHz by default).
public struct EnergyTrack: Codable, Equatable, Sendable {
    public let windowSamples: Int
    public let sampleRate: Double
    public private(set) var values: [Float]
    private var pendingSquares: Float = 0
    private var pendingCount = 0

    public init(windowSamples: Int = 1600, sampleRate: Double = 16000, values: [Float] = []) {
        self.windowSamples = windowSamples
        self.sampleRate = sampleRate
        self.values = values
    }

    enum CodingKeys: String, CodingKey { case windowSamples, sampleRate, values }

    public mutating func append<S: Sequence>(samples: S) where S.Element == Float {
        for sample in samples {
            pendingSquares += sample * sample
            pendingCount += 1
            if pendingCount == windowSamples { closeWindow() }
        }
    }

    /// Flushes a final partial window.
    public mutating func finish() {
        if pendingCount > 0 { closeWindow() }
    }

    private mutating func closeWindow() {
        values.append((pendingSquares / Float(pendingCount)).squareRoot())
        pendingSquares = 0
        pendingCount = 0
    }

    /// Sum of window values overlapping `start…end` seconds.
    public func energy(from start: Double, to end: Double) -> Float {
        let windowSeconds = Double(windowSamples) / sampleRate
        // Small tolerance so 0.3 s is not pushed into the next window by floating-point error.
        let first = max(0, Int((start / windowSeconds + 1e-9).rounded(.down)))
        let last = min(values.count, Int((end / windowSeconds - 1e-9).rounded(.up)))
        guard first < last else { return 0 }
        return values[first..<last].reduce(0, +)
    }

    /// Mic vs system energy for each turn, in turn order.
    public static func speakerEnergies(turns: [Turn], mic: EnergyTrack, system: EnergyTrack) -> [SpeakerEnergy] {
        turns.map {
            SpeakerEnergy(
                speakerID: $0.speakerID,
                mic: mic.energy(from: $0.start, to: $0.end),
                system: system.energy(from: $0.start, to: $0.end)
            )
        }
    }
}
