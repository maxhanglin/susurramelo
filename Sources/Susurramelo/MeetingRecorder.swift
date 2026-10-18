import AVFoundation
import CoreAudio

/// Records a meeting as two compressed files in `folder`: `mic.m4a` (microphone) and
/// `system.m4a` (everything the Mac plays, via a Core Audio process tap, macOS 14.2+).
final class MeetingRecorder {
    enum RecorderError: LocalizedError {
        case coreAudio(String, OSStatus)

        var errorDescription: String? {
            switch self {
            case let .coreAudio(step, status): "System audio capture failed (\(step), \(status))"
            }
        }
    }

    static func micURL(in folder: URL) -> URL { folder.appendingPathComponent("mic.m4a") }
    static func systemURL(in folder: URL) -> URL { folder.appendingPathComponent("system.m4a") }

    private let folder: URL
    private let mic = MicFileRecorder()
    private let system = SystemAudioFileRecorder()

    init(folder: URL) {
        self.folder = folder
    }

    func start() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try system.start(writingTo: Self.systemURL(in: folder))
        do {
            try mic.start(writingTo: Self.micURL(in: folder))
        } catch {
            system.stop()
            throw error
        }
    }

    func stop() {
        mic.stop()
        system.stop()
    }
}

/// AAC settings used while recording (decoded and mixed after the meeting).
private func aacSettings(sampleRate: Double, channels: Int) -> [String: Any] {
    [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: channels,
        AVEncoderBitRateKey: 48_000 * channels,
    ]
}

/// Writes PCM buffers to a compressed file on a background queue so audio threads never block.
final class BufferedFileWriter {
    private let queue = DispatchQueue(label: "susurramelo.meeting-writer")
    private var file: AVAudioFile?

    init(url: URL, format: AVAudioFormat) throws {
        file = try AVAudioFile(
            forWriting: url,
            settings: aacSettings(sampleRate: format.sampleRate, channels: Int(min(format.channelCount, 2))),
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    /// Takes ownership of a copied buffer.
    func write(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self, let file = self.file else { return }
            do {
                // AVAudioFile only accepts buffers in its processing format (deinterleaved Float32);
                // system-audio taps deliver interleaved buffers, so convert those first.
                try file.write(from: self.matching(buffer, to: file.processingFormat))
            } catch {
                Log.dictation.error("Meeting audio write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var converter: AVAudioConverter?

    private func matching(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard buffer.format != format else { return buffer }
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter, let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
            throw MeetingRecorder.RecorderError.coreAudio("unsupported buffer format", -1)
        }
        // Same sample rate, only the channel layout differs, so a single convert call is enough.
        try converter.convert(to: output, from: buffer)
        return output
    }

    func close() {
        // Closing the file finalizes the container.
        queue.sync { file = nil }
    }
}

// MARK: - Microphone

private final class MicFileRecorder {
    private let engine = AVAudioEngine()
    private var writer: BufferedFileWriter?

    func start(writingTo url: URL) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Mono is enough for the microphone.
        guard let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false) else { return }
        let writer = try BufferedFileWriter(url: url, format: mono)
        self.writer = writer
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate / 10), format: format) { buffer, _ in
            guard let copy = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength),
                  let source = buffer.floatChannelData, let target = copy.floatChannelData else { return }
            copy.frameLength = buffer.frameLength
            // Take the first channel (built-in and most USB mics are mono anyway).
            target[0].update(from: source[0], count: Int(buffer.frameLength))
            writer.write(copy)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        writer?.close()
        writer = nil
    }
}

// MARK: - System audio (Core Audio process tap)

private final class SystemAudioFileRecorder {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var writer: BufferedFileWriter?
    private let ioQueue = DispatchQueue(label: "susurramelo.system-audio")

    func start(writingTo url: URL) throws {
        // Tap every process's output, mixed down to stereo. Requires "System Audio Recording" permission.
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Susurramelo meeting"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "create tap")

        let outputUID = try defaultOutputDeviceUID()
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Susurramelo Meeting Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate device")

        var streamDescription = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &streamDescription), "read tap format")
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw MeetingRecorder.RecorderError.coreAudio("unsupported tap format", -1)
        }
        let writer = try BufferedFileWriter(url: url, format: format)
        self.writer = writer

        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, ioQueue) { _, inputData, _, _, _ in
            guard let source = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inputData, deallocator: nil),
                  let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: source.frameLength) else { return }
            copy.frameLength = source.frameLength
            let from = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
            let to = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for (src, dst) in zip(from, to) where src.mData != nil && dst.mData != nil {
                memcpy(dst.mData, src.mData, Int(min(src.mDataByteSize, dst.mDataByteSize)))
            }
            writer.write(copy)
        }, "create IO proc")
        try check(AudioDeviceStart(aggregateID, ioProcID), "start device")
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            if let ioProcID { AudioDeviceDestroyIOProcID(aggregateID, ioProcID) }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        writer?.close()
        writer = nil
    }

    private func defaultOutputDeviceUID() throws -> String {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID), "default output")
        var uid: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        address.mSelector = kAudioDevicePropertyDeviceUID
        try check(withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0) }, "output UID")
        return uid as String
    }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw MeetingRecorder.RecorderError.coreAudio(step, status) }
    }
}
