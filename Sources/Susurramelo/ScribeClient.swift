import Foundation
import SusurrameloCore

/// One dictation session against ElevenLabs Scribe v2 Realtime.
/// Audio is streamed while the key is held; `commit()` asks for the final transcript.
final class ScribeClient {
    enum Outcome {
        case transcript(String)
        case failure(String)
    }

    private let task: URLSessionWebSocketTask
    private let queue = DispatchQueue(label: "susurramelo.scribe")
    private var lastPartial = ""
    private var committed = false
    private var finished = false
    private var completion: ((Outcome) -> Void)?
    private var earlyOutcome: Outcome?

    /// Delivered on the main queue.
    var onPartial: ((String) -> Void)?

    init(apiKey: String, languageCode: String?) {
        var request = URLRequest(url: ScribeProtocol.realtimeURL(languageCode: languageCode))
        request.setValue(apiKey, forHTTPHeaderField: ScribeProtocol.apiKeyHeader)
        task = URLSession.shared.webSocketTask(with: request)
    }

    func connect() {
        task.resume()
        receive()
    }

    /// Thread-safe; called from the audio thread.
    func send(_ audio: Data, commit: Bool = false) {
        guard let message = try? ScribeProtocol.audioChunkMessage(audio, commit: commit, sampleRate: PCM.sampleRate) else { return }
        task.send(.string(message)) { [weak self] error in
            if let error { self?.finish(.failure("Send failed: \(error.localizedDescription)")) }
        }
    }

    /// Sends the trailing audio with `commit: true` and waits for `committed_transcript`.
    func commit(trailingAudio: Data, timeout: TimeInterval = 10, completion: @escaping (Outcome) -> Void) {
        queue.async {
            // A server error may have ended the session before the key was released.
            if self.finished {
                let outcome = self.earlyOutcome ?? .failure("Session ended before commit")
                DispatchQueue.main.async { completion(outcome) }
                return
            }
            self.completion = completion
            self.committed = true
            // Always send something with the commit flag; 100 ms of silence if nothing is pending.
            let audio = trailingAudio.isEmpty ? Data(count: PCM.sampleRate / 10 * 2) : trailingAudio
            self.send(audio, commit: true)
        }
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self else { return }
            // Fall back to the last partial rather than losing what the user said.
            self.finish(self.lastPartial.isEmpty ? .failure("Timed out waiting for transcript") : .transcript(self.lastPartial))
        }
    }

    func cancel() {
        queue.async {
            self.finished = true
            self.completion = nil
        }
        task.cancel(with: .normalClosure, reason: nil)
    }

    private func receive() {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(.string(text)):
                self.handle(ScribeProtocol.decodeEvent(text))
                self.receive()
            case let .success(.data(data)):
                self.handle(ScribeProtocol.decodeEvent(String(decoding: data, as: UTF8.self)))
                self.receive()
            case let .failure(error):
                self.finish(.failure("Connection closed: \(error.localizedDescription)"))
            @unknown default:
                self.receive()
            }
        }
    }

    private func handle(_ event: ScribeProtocol.Event) {
        switch event {
        case let .partialTranscript(text):
            queue.async { self.lastPartial = text }
            DispatchQueue.main.async { self.onPartial?(text) }
        case let .committedTranscript(text):
            queue.async {
                // Committed segments before our commit (none with manual strategy) are ignored.
                guard self.committed else { return }
                self.finish(.transcript(text))
            }
        case let .serverError(type, message):
            finish(.failure([type, message].compactMap { $0 }.joined(separator: ": ")))
        case .sessionStarted, .ignored, .undecodable:
            break
        }
    }

    private func finish(_ outcome: Outcome) {
        queue.async {
            guard !self.finished else { return }
            self.finished = true
            let completion = self.completion
            self.completion = nil
            if completion == nil { self.earlyOutcome = outcome }
            self.task.cancel(with: .normalClosure, reason: nil)
            DispatchQueue.main.async { completion?(outcome) }
        }
    }
}
