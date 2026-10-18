import AVFoundation
import SusurrameloCore

/// After a meeting: mixes `mic.m4a` and `system.m4a` into a 16 kHz mono `audio.m4a` (what gets
/// transcribed) and measures each channel's loudness for "Me" detection. Streams in 1 s blocks,
/// so long meetings never sit in memory.
enum MeetingAudioProcessor {
    struct Output {
        let duration: TimeInterval
        let mic: EnergyTrack
        let system: EnergyTrack
    }

    static let sampleRate: Double = 16000

    static func process(mic micURL: URL, system systemURL: URL, into outputURL: URL) throws -> Output {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        var micReader = try MonoReader(url: micURL, targetFormat: format)
        var systemReader = try MonoReader(url: systemURL, targetFormat: format)
        try? FileManager.default.removeItem(at: outputURL)
        let output = try AVAudioFile(
            forWriting: outputURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        var micTrack = EnergyTrack()
        var systemTrack = EnergyTrack()
        var frames = 0
        let block = AVAudioFrameCount(sampleRate)
        while true {
            let mic = try micReader?.read(block) ?? []
            let system = try systemReader?.read(block) ?? []
            if mic.isEmpty { micReader = nil }
            if system.isEmpty { systemReader = nil }
            let count = max(mic.count, system.count)
            if count == 0 { break }

            // Pad the shorter channel with silence so both stay aligned.
            let micBlock = mic + [Float](repeating: 0, count: count - mic.count)
            let systemBlock = system + [Float](repeating: 0, count: count - system.count)
            micTrack.append(samples: micBlock)
            systemTrack.append(samples: systemBlock)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { break }
            buffer.frameLength = AVAudioFrameCount(count)
            let out = buffer.floatChannelData![0]
            for i in 0..<count {
                out[i] = max(-1, min(1, micBlock[i] + systemBlock[i]))
            }
            try output.write(from: buffer)
            frames += count
        }
        micTrack.finish()
        systemTrack.finish()
        return Output(duration: Double(frames) / sampleRate, mic: micTrack, system: systemTrack)
    }
}

/// Reads any audio file as mono Float32 at the target rate, block by block.
private struct MonoReader {
    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let targetFormat: AVAudioFormat
    private var finished = false

    init?(url: URL, targetFormat: AVAudioFormat) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        file = try AVAudioFile(forReading: url)
        // Downmix to mono first; AVAudioConverter averages channels when channel counts differ.
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else { return nil }
        self.converter = converter
        self.targetFormat = targetFormat
    }

    mutating func read(_ frames: AVAudioFrameCount) throws -> [Float] {
        guard !finished, let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frames) else { return [] }
        let file = self.file
        let inputCapacity = AVAudioFrameCount(Double(frames) * file.processingFormat.sampleRate / targetFormat.sampleRate) + 1024
        var reachedEnd = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: inputCapacity) else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            do { try file.read(into: input) } catch {
                inputStatus.pointee = .endOfStream
                reachedEnd = true
                return nil
            }
            if input.frameLength == 0 {
                inputStatus.pointee = .endOfStream
                reachedEnd = true
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }
        if let error { throw error }
        if status == .endOfStream || (reachedEnd && out.frameLength == 0) { finished = true }
        guard out.frameLength > 0, let data = out.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: data, count: Int(out.frameLength)))
    }
}
