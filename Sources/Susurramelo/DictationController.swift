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
    private var recordingStartedAt: Date?
    private let preferences: Preferences
    private let history: HistoryController
    private let dictionary: DictionaryController

    var onStatusChange: ((Status) -> Void)?

    init(preferences: Preferences, history: HistoryController, dictionary: DictionaryController) {
        self.preferences = preferences
        self.history = history
        self.dictionary = dictionary
    }

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
        let language = preferences.languageCode.isEmpty ? nil : preferences.languageCode
        let client = ScribeClient(apiKey: apiKey, languageCode: language, keyterms: dictionary.dictionary.keyterms)
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
        recordingStartedAt = Date()
        status = .recording
    }

    private func commitRecording() {
        guard let client, let capture else { return }
        capture.stop()
        self.capture = nil
        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        status = .transcribing
        client.commit(trailingAudio: Data()) { [weak self] outcome in
            // Ignore completions from a session that is no longer current (e.g. cancelled with Esc).
            guard let self, self.client === client else { return }
            self.client = nil
            switch outcome {
            case let .transcript(text):
                let trimmed = self.dictionary.dictionary.apply(to: text).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    self.status = .idle
                    return
                }
                let appName = NSWorkspace.shared.frontmostApplication?.localizedName
                self.history.record(text: trimmed, duration: duration, appName: appName)
                self.insert(trimmed)
            case let .failure(message):
                self.status = .error(message)
            }
        }
    }

    /// Pastes the most recent transcript at the cursor (Ctrl+Cmd+V).
    func pasteLast() {
        guard status == .idle || isErrorStatus, let last = history.history.last else { return }
        insert(last.text)
    }

    private var isErrorStatus: Bool {
        if case .error = status { return true }
        return false
    }

    private func insert(_ text: String) {
        if TextInserter.insert(text) == .copiedOnly {
            status = .error("Accessibility permission missing — text copied, press Cmd+V")
        } else {
            status = .idle
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
