import Foundation

/// Converts microphone samples into a 0…1 loudness value for the waveform.
public enum AudioLevel {
    /// Quietest level shown; anything below reads as silence.
    public static let floorDecibels: Float = -60

    /// RMS of the samples mapped linearly from `floorDecibels`…0 dBFS onto 0…1.
    public static func normalized<C: Collection>(samples: C) -> Float where C.Element == Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        guard meanSquare > 0 else { return 0 }
        let decibels = 10 * log10(meanSquare)
        return min(1, max(0, (decibels - floorDecibels) / -floorDecibels))
    }
}

/// Fixed-size rolling window of recent levels, oldest first.
public struct LevelHistory: Sendable {
    public private(set) var values: [Float]

    public init(capacity: Int) {
        values = Array(repeating: 0, count: capacity)
    }

    public mutating func append(_ level: Float) {
        values.removeFirst()
        values.append(level)
    }
}
