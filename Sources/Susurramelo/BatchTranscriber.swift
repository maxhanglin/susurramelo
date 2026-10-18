import Foundation

/// Uploads a recorded file to ElevenLabs Scribe v2 batch (`POST /v1/speech-to-text`).
struct BatchTranscriber {
    struct Options {
        var diarize = true
        /// Transcribe each channel separately (mic vs system audio). Each channel is billed.
        var multiChannel = false
        var numSpeakers: Int?
        var languageCode: String?
        var keyterms: [String] = []
    }

    enum BatchError: LocalizedError {
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case let .http(status, body): "Transcription failed (HTTP \(status)): \(body.prefix(300))"
            }
        }
    }

    static let endpoint = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!

    let apiKey: String

    /// Returns the raw JSON response.
    func transcribe(fileURL: URL, options: Options) async throws -> Data {
        let boundary = "susurramelo-\(UUID().uuidString)"
        var fields: [(String, String)] = [
            ("model_id", "scribe_v2"),
            ("timestamps_granularity", "word"),
            ("tag_audio_events", "false"),
            ("diarize", options.diarize ? "true" : "false"),
        ]
        if options.multiChannel {
            fields.append(("use_multi_channel", "true"))
            fields.append(("multichannel_output_style", "combined"))
        }
        if let numSpeakers = options.numSpeakers { fields.append(("num_speakers", String(numSpeakers))) }
        if let language = options.languageCode, !language.isEmpty { fields.append(("language_code", language)) }
        for term in options.keyterms { fields.append(("keyterms", term)) }

        let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(boundary).multipart")
        defer { try? FileManager.default.removeItem(at: bodyURL) }
        try writeMultipartBody(to: bodyURL, boundary: boundary, fields: fields, fileURL: fileURL)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 * 60
        // Streams the body from disk, so long recordings are not loaded into memory.
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw BatchError.http(status, String(decoding: data, as: UTF8.self)) }
        return data
    }

    private func writeMultipartBody(to url: URL, boundary: String, fields: [(String, String)], fileURL: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        func write(_ string: String) throws { try handle.write(contentsOf: Data(string.utf8)) }
        for (name, value) in fields {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        let mime = fileURL.pathExtension.lowercased() == "wav" ? "audio/wav" : "audio/mp4"
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: \(mime)\r\n\r\n")
        let input = try FileHandle(forReadingFrom: fileURL)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
            try handle.write(contentsOf: chunk)
        }
        try write("\r\n--\(boundary)--\r\n")
    }
}

/// `Susurramelo --batch-test <file> <mode> <out.json>` with mode `diarize`, `multichannel` or `both`.
/// Development aid for comparing transcription modes; uses the Keychain API key (never printed).
enum BatchTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--batch-test"), index + 3 < args.count else { return }
        let file = URL(fileURLWithPath: args[index + 1])
        let mode = args[index + 2]
        let out = URL(fileURLWithPath: args[index + 3])
        guard let apiKey = KeychainStore.load() else { print("no API key"); exit(1) }
        var options = BatchTranscriber.Options()
        options.diarize = mode != "multichannel"
        options.multiChannel = mode != "diarize"
        Task {
            do {
                let started = Date()
                let data = try await BatchTranscriber(apiKey: apiKey).transcribe(fileURL: file, options: options)
                try data.write(to: out)
                print("OK \(mode): \(data.count) bytes in \(String(format: "%.1f", Date().timeIntervalSince(started))) s → \(out.path)")
                exit(0)
            } catch {
                print("FAILED \(mode): \(error.localizedDescription)")
                exit(1)
            }
        }
        RunLoop.main.run()
    }
}
