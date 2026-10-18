import AVFoundation
import SusurrameloCore

/// Captures the default microphone and delivers 16 kHz mono Int16 PCM chunks.
final class AudioCapture {
    enum CaptureError: Error {
        case converterUnavailable
    }

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(PCM.sampleRate),
        channels: 1,
        interleaved: false
    )!

    /// Called on the audio thread with each converted chunk.
    var onChunk: ((Data) -> Void)?
    /// Called on the audio thread with the chunk's loudness (0…1).
    var onLevel: ((Float) -> Void)?

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw CaptureError.converterUnavailable
        }
        self.converter = converter

        // ~20 ms buffers: smooth waveform updates and low streaming latency.
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate / 50)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.convert(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
    }

    private func convert(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, output.frameLength > 0, let channel = output.floatChannelData?[0] else { return }
        let samples = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
        onLevel?(AudioLevel.normalized(samples: samples))
        onChunk?(PCM.int16LittleEndianData(from: samples))
    }
}
