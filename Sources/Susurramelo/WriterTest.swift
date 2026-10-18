import AVFoundation

/// `Susurramelo --writer-test <out.m4a>` writes 1 s of interleaved stereo Float32 audio — the format
/// a Core Audio process tap delivers — through the meeting file writer and reports how much was saved.
enum WriterTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--writer-test"), index + 1 < args.count else { return }
        let url = URL(fileURLWithPath: args[index + 1])
        try? FileManager.default.removeItem(at: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: true)!
        do {
            let writer = try BufferedFileWriter(url: url, format: format)
            for block in 0..<50 {
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960)!
                buffer.frameLength = 960
                let samples = buffer.floatChannelData![0] // interleaved: L R L R …
                for i in 0..<960 {
                    let value = Float(sin(Double(block * 960 + i) * 2 * .pi * 440 / 48000)) * 0.5
                    samples[i * 2] = value
                    samples[i * 2 + 1] = value
                }
                writer.write(buffer)
            }
            writer.close()
            let file = try AVAudioFile(forReading: url)
            print("saved frames: \(file.length) (expected ~48000), channels: \(file.fileFormat.channelCount)")
            exit(file.length > 40000 ? 0 : 1)
        } catch {
            print("FAILED: \(error.localizedDescription)")
            exit(1)
        }
    }
}
