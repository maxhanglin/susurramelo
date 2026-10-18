import AppKit
import SusurrameloCore

/// Wires the dictation key, Esc, capture, transcription, the floating bar and insertion.
/// Runs on the main thread.
final class DictationController {
    enum Status: Equatable {
        case idle
        case recording
        case handsFree
        case transcribing
        case error(String)
    }

    private var gesture = DictationGesture(minimumHold: 0.25, doubleTapWindow: 0.4)
    private let hotkey = HotkeyMonitor()
    private let escape = EscapeMonitor()
    private let bar = FloatingBar()
    private var capture: AudioCapture?
    private var client: ScribeClient?

    /// Empty means automatic language detection.
    var languageCode: String?
    var onStatusChange: ((Status) -> Void)?

    private(set) var status: Status = .idle {
        didSet {
            Log.dictation.info("Status: \(String(describing: self.status), privacy: .public)")
            onStatusChange?(status)
            renderBar()
        }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func start() {
        hotkey.onPress = { [weak self] in self?.handleKey(.keyDown(at: self?.now ?? 0)) }
        hotkey.onRelease = { [weak self] in self?.handleKey(.keyUp(at: self?.now ?? 0)) }
        hotkey.start()
        escape.onEscape = { [weak self] in self?.handleEscape() }
        escape.start()
    }

    private func handleKey(_ input: DictationGesture.Input) {
        // One session at a time: ignore new presses until the previous transcript is pasted.
        if case .keyDown = input, status == .transcribing { return }
        perform(gesture.handle(input))
    }

    private func handleEscape() {
        if status == .transcribing {
            Log.dictation.info("Esc during transcription: discarding")
            cancelSession()
            return
        }
        perform(gesture.handle(.escape))
    }

    private func perform(_ action: DictationGesture.Action) {
        switch action {
        case .startRecording:
            beginRecording()
        case let .awaitSecondTap(deadline):
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline - now)) { [weak self] in
                guard let self else { return }
                self.perform(self.gesture.handle(.tapTimeout(at: self.now)))
            }
        case .lockHandsFree:
            if capture != nil { status = .handsFree }
        case .stopAndCommit:
            commitRecording()
        case .cancel:
            cancelSession()
        case .none:
            break
        }
    }

    private func beginRecording() {
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else {
            status = .error("Set your ElevenLabs API key first")
            return
        }
        let client = ScribeClient(apiKey: apiKey, languageCode: languageCode)
        let capture = AudioCapture()
        var bytesSent = 0
        capture.onChunk = { [weak client] chunk in
            bytesSent += chunk.count
            if bytesSent == chunk.count { Log.dictation.info("First audio chunk captured (\(chunk.count) bytes)") }
            client?.send(chunk)
        }
        capture.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.bar.push(level: level) }
        }
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
            // Ignore completions from a session that is no longer current (e.g. cancelled with Esc).
            guard let self, self.client === client else { return }
            self.client = nil
            switch outcome {
            case let .transcript(text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, TextInserter.insert(trimmed) == .copiedOnly {
                    self.status = .error("Accessibility permission missing — text copied, press Cmd+V")
                } else {
                    self.status = .idle
                }
            case let .failure(message):
                self.status = .error(message)
            }
        }
    }

    private func cancelSession() {
        capture?.stop()
        capture = nil
        client?.cancel()
        client = nil
        status = .idle
    }

    private func renderBar() {
        switch status {
        case .idle: bar.hide()
        case .recording: bar.show(.recording)
        case .handsFree: bar.show(.handsFree)
        case .transcribing: bar.show(.transcribing)
        case let .error(message): bar.flashError(message)
        }
    }
}
