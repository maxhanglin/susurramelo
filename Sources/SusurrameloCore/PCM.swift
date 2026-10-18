import Foundation

/// Helpers for the raw audio format ElevenLabs expects (`pcm_16000`: 16-bit signed little-endian mono).
public enum PCM {
    public static let sampleRate = 16_000

    /// Converts normalized Float32 samples (-1...1) into 16-bit little-endian PCM bytes.
    /// Out-of-range samples are clamped so clipping never wraps around.
    public static func int16LittleEndianData<S: Sequence>(from samples: S) -> Data where S.Element == Float {
        var data = Data()
        data.reserveCapacity(samples.underestimatedCount * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let value = Int16(clamped * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        }
        return data
    }
}
