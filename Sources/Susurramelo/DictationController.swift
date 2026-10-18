import AppKit
import SusurrameloCore

/// Wires push-to-talk to capture, transcription and insertion. Runs on the main thread.
final class DictationController {
    enum Status: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }

    private var pushToTalk = PushToTalk(minimumHold: 0.25)
    private let hotkey = HotkeyMonitor()
    private var capture: AudioCapture?
    private var client: ScribeClient?

    /// Empty means automatic language detection.
    var languageCode: String?
    var onStatusChange: ((Status) -> Void)?

    private(set) var status: Status = .idle {
        didSet { onStatusChange?(status) }
    }

    func start() {
        hotkey.onPress = { [weak self] in self?.apply(.keyDown(at: ProcessInfo.processInfo.systemUptime)) }
        hotkey.onRelease = { [weak self] in self?.apply(.keyUp(at: ProcessInfo.processInfo.systemUptime)) }
        hotkey.start()
    }

    private func apply(_ input: PushToTalk.Input) {
        // One session at a time: ignore new presses until the previous transcript is pasted.
        if case .keyDown = input, status == .transcribing { return }
        switch pushToTalk.handle(input) {
        case .startRecording: beginRecording()
        case .stopAndCommit: commitRecording()
        case .cancel: cancelRecording()
        case .none: break
        }
    }

    private func beginRecording() {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else {
            status = .error("Set your ElevenLabs API key first")
            return
        }
        let client = ScribeClient(apiKey: apiKey, languageCode: languageCode)
        let capture = AudioCapture()
        capture.onChunk = { [weak client] chunk in client?.send(chunk) }
        client.connect()
        do {
            try capture.start()
        } catch {
            client.cancel()
            status = .error("Microphone unavailable: \(error.localizedDescription)")
            return
        }
        self.client = client
        self.capture = capture
        status = .recording
    }

    private func commitRecording() {
        guard let client, let capture else { return }
        capture.stop()
        self.capture = nil
        status = .transcribing
        client.commit(trailingAudio: Data()) { [weak self] outcome in
            // Ignore completions from a session that is no longer current.
            guard let self, self.client === client else { return }
            self.client = nil
            switch outcome {
            case let .transcript(text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { TextInserter.insert(trimmed) }
                self.status = .idle
            case let .failure(message):
                self.status = .error(message)
            }
        }
    }

    private func cancelRecording() {
        capture?.stop()
        capture = nil
        client?.cancel()
        client = nil
        status = .idle
    }
}
