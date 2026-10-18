import AppKit
import Network
import SusurrameloCore

/// Owns the meeting list, the active recording and post-meeting transcription. Main thread.
final class NotetakerController: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var recordingID: UUID?
    @Published private(set) var recordingStartedAt: Date?

    let store: MeetingStore
    private let preferences: Preferences
    private let dictionary: DictionaryController
    private var recorder: MeetingRecorder?
    private let retryPolicy = RetryPolicy()
    private let pathMonitor = NWPathMonitor()

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Susurramelo/Meetings")
    }

    init(preferences: Preferences, dictionary: DictionaryController, directory: URL = NotetakerController.defaultDirectory) {
        self.preferences = preferences
        self.dictionary = dictionary
        store = MeetingStore(directory: directory)
        reload()
        // A meeting left "recording" or "transcribing" by a crash or quit can be retried.
        for meeting in meetings where meeting.status == .recording || meeting.status == .transcribing {
            update(meeting.id) { $0.status = .failed("Interrupted before the transcript was ready.") }
        }
        // Retry uploads that failed for lack of network as soon as a connection is available
        // (the first update arrives right away, which also covers the app launching online).
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async { self?.retryMeetingsWaitingForNetwork() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "susurramelo.network"))
    }

    deinit {
        pathMonitor.cancel()
    }

    private func retryMeetingsWaitingForNetwork() {
        for meeting in meetings where meeting.waitingForNetwork == true {
            if case .failed = meeting.status {
                Log.dictation.info("Network is back; retrying a meeting transcription")
                transcribe(meeting.id)
            }
        }
    }

    var isRecording: Bool { recordingID != nil }

    func reload() {
        meetings = (try? store.loadAll()) ?? []
    }

    // MARK: Recording

    func startRecording() throws {
        guard recordingID == nil else { return }
        let now = Date()
        let meeting = Meeting(title: "Meeting · " + now.formatted(date: .abbreviated, time: .shortened), date: now)
        try store.save(meeting)
        let recorder = MeetingRecorder(folder: store.folder(for: meeting.id))
        do {
            try recorder.start()
        } catch {
            try? store.delete(meeting.id)
            throw error
        }
        self.recorder = recorder
        recordingID = meeting.id
        recordingStartedAt = now
        reload()
        Log.dictation.info("Meeting recording started")
    }

    func stopRecording() {
        guard let id = recordingID else { return }
        recorder?.stop()
        recorder = nil
        recordingID = nil
        recordingStartedAt = nil
        Log.dictation.info("Meeting recording stopped")
        transcribe(id)
    }

    // MARK: Transcription

    /// Mixes the recording, uploads it with speaker separation and stores the transcript.
    /// Network errors, rate limits and server errors are retried with increasing waits; if the
    /// failure was for lack of network, the meeting is retried again when the connection returns.
    func transcribe(_ id: UUID) {
        if let meeting = meetings.first(where: { $0.id == id }), meeting.status == .transcribing { return }
        update(id) {
            $0.status = .transcribing
            $0.waitingForNetwork = nil
        }
        let folder = store.folder(for: id)
        let language = preferences.languageCode.isEmpty ? nil : preferences.languageCode
        let keyterms = dictionary.dictionary.keyterms
        let policy = retryPolicy
        Task.detached(priority: .userInitiated) { [weak self] in
            var attempt = 0
            var result: Result<MeetingPipeline.Result, Error>
            while true {
                attempt += 1
                do {
                    result = .success(try await MeetingPipeline.run(folder: folder, languageCode: language, keyterms: keyterms))
                    break
                } catch {
                    result = .failure(error)
                    let failure = MeetingPipeline.classify(error)
                    guard RetryPolicy.isRetryable(failure), let delay = policy.delay(afterAttempt: attempt) else { break }
                    Log.dictation.info("Meeting upload failed (attempt \(attempt)); retrying in \(Int(delay)) s")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            let owner = self
            let finalResult = result
            await MainActor.run {
                guard let self = owner else { return }
                switch finalResult {
                case let .success(output):
                    self.update(id) {
                        $0.turns = output.turns
                        $0.duration = output.duration
                        $0.meSpeakerID = output.meSpeakerID
                        $0.languageCode = output.languageCode
                        $0.status = .done
                    }
                case let .failure(error):
                    Log.dictation.error("Meeting transcription failed: \(error.localizedDescription, privacy: .public)")
                    let waits = RetryPolicy.waitsForNetwork(MeetingPipeline.classify(error))
                    self.update(id) {
                        $0.status = .failed(waits
                            ? "No internet connection — will retry automatically when you're back online."
                            : error.localizedDescription)
                        $0.waitingForNetwork = waits ? true : nil
                    }
                }
            }
        }
    }

    // MARK: Editing

    func rename(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.title = trimmed }
    }

    func renameSpeaker(_ id: UUID, speakerID: String, to name: String) {
        update(id) { $0.speakerNames[speakerID] = name.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func delete(_ id: UUID) {
        guard id != recordingID else { return }
        try? store.delete(id)
        reload()
    }

    private func update(_ id: UUID, _ change: (inout Meeting) -> Void) {
        guard var meeting = meetings.first(where: { $0.id == id }) ?? (try? store.loadAll())?.first(where: { $0.id == id }) else { return }
        change(&meeting)
        do { try store.save(meeting) } catch {
            Log.dictation.error("Could not save meeting: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }
}

/// Post-meeting processing for one meeting folder (no UI state; runs off the main thread).
enum MeetingPipeline {
    struct Result {
        let turns: [Turn]
        let duration: TimeInterval
        let meSpeakerID: String?
        let languageCode: String?
    }

    /// Maps an upload error to the retry policy's categories.
    static func classify(_ error: Error) -> UploadFailure {
        if error is URLError { return .offline }
        if case let BatchTranscriber.BatchError.http(status, _) = error { return .http(status) }
        return .other
    }

    enum PipelineError: LocalizedError {
        case missingAPIKey

        var errorDescription: String? { "Set your ElevenLabs API key first." }
    }

    static func run(folder: URL, languageCode: String?, keyterms: [String]) async throws -> Result {
        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else { throw PipelineError.missingAPIKey }
        let audioURL = folder.appendingPathComponent("audio.m4a")
        let energyURL = folder.appendingPathComponent("energy.json")

        // Mix once; a retry after a failed upload reuses the mixed file.
        let mic: EnergyTrack
        let system: EnergyTrack
        if let saved = try? JSONDecoder().decode([EnergyTrack].self, from: Data(contentsOf: energyURL)),
           saved.count == 2, FileManager.default.fileExists(atPath: audioURL.path) {
            (mic, system) = (saved[0], saved[1])
        } else {
            let output = try MeetingAudioProcessor.process(
                mic: MeetingRecorder.micURL(in: folder),
                system: MeetingRecorder.systemURL(in: folder),
                into: audioURL
            )
            (mic, system) = (output.mic, output.system)
            try JSONEncoder().encode([mic, system]).write(to: energyURL, options: .atomic)
        }

        var options = BatchTranscriber.Options()
        options.diarize = true
        options.languageCode = languageCode
        options.keyterms = keyterms
        let data = try await BatchTranscriber(apiKey: apiKey).transcribe(fileURL: audioURL, options: options)
        let batch = try ScribeBatchResult.decode(data)
        let turns = TranscriptTurns.build(from: batch.words)
        let me = MeDetector.meSpeaker(from: EnergyTrack.speakerEnergies(turns: turns, mic: mic, system: system))

        // The mixed file is kept for playback/retry; the raw channel files are no longer needed.
        try? FileManager.default.removeItem(at: MeetingRecorder.micURL(in: folder))
        try? FileManager.default.removeItem(at: MeetingRecorder.systemURL(in: folder))

        let duration = batch.durationSeconds ?? Double(mic.values.count) * Double(mic.windowSamples) / mic.sampleRate
        return Result(turns: turns, duration: duration, meSpeakerID: me, languageCode: batch.languageCode)
    }
}

/// `Susurramelo --meeting-test <mic-file> <system-file>` runs the post-meeting pipeline on two
/// existing files in a temporary folder and prints the transcript (development aid).
enum MeetingPipelineTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--meeting-test"), index + 2 < args.count else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("susurramelo-meeting-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: args[index + 1]), to: MeetingRecorder.micURL(in: folder))
            try FileManager.default.copyItem(at: URL(fileURLWithPath: args[index + 2]), to: MeetingRecorder.systemURL(in: folder))
        } catch {
            print("FAILED: \(error.localizedDescription)")
            exit(1)
        }
        Task {
            defer { try? FileManager.default.removeItem(at: folder) }
            do {
                let result = try await MeetingPipeline.run(folder: folder, languageCode: nil, keyterms: [])
                var meeting = Meeting(title: "Test", date: Date())
                meeting.turns = result.turns
                meeting.meSpeakerID = result.meSpeakerID
                meeting.duration = result.duration
                print("me=\(result.meSpeakerID ?? "none") duration=\(Meeting.clock(result.duration))")
                print(meeting.plainText)
                exit(0)
            } catch {
                print("FAILED: \(error.localizedDescription)")
                exit(1)
            }
        }
        RunLoop.main.run()
    }
}
