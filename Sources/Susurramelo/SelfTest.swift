import Foundation
import SusurrameloCore

/// `Susurramelo --self-test <file.wav>` streams a 16 kHz mono 16-bit WAV through the same
/// Scribe client used for dictation and prints the outcome. It uses the Keychain API key and
/// never prints it. Create a test file with:
/// `say -o /tmp/t.aiff "Hola, esto es una prueba" && afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/t.aiff /tmp/t.wav`
enum SelfTest {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--self-test") else { return }
        guard index + 1 < args.count else { fail("usage: Susurramelo --self-test <file.wav>") }
        guard let wav = FileManager.default.contents(atPath: args[index + 1]), let pcm = pcmData(fromWAV: wav) else {
            fail("could not read PCM data from \(args[index + 1])")
        }
        guard let apiKey = KeychainStore.load(), !apiKey.isEmpty else { fail("no API key in the Keychain") }

        print("Streaming \(pcm.count) bytes (\(Double(pcm.count) / 2 / Double(PCM.sampleRate)) s)…")
        // Optional: --keyterms "Word1,Word2" to check the server accepts them.
        let keyterms = args.firstIndex(of: "--keyterms").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }?
            .split(separator: ",").map(String.init) ?? []
        if !keyterms.isEmpty { print("Keyterms: \(keyterms)") }
        let client = ScribeClient(apiKey: apiKey, languageCode: nil, keyterms: keyterms)
        client.onPartial = { print("partial: \($0)") }
        client.connect()
        // Real-time pacing: 100 ms chunks every 100 ms, like the microphone.
        let chunkSize = PCM.sampleRate / 10 * 2
        var offset = 0
        while offset < pcm.count {
            let end = min(offset + chunkSize, pcm.count)
            client.send(pcm.subdata(in: offset..<end))
            offset = end
            Thread.sleep(forTimeInterval: 0.1)
        }
        client.commit(trailingAudio: Data()) { outcome in
            switch outcome {
            case let .transcript(text):
                print("TRANSCRIPT: \(text)")
                exit(0)
            case let .failure(message):
                fail(message)
            }
        }
        RunLoop.main.run()
    }

    /// Returns the bytes of the `data` chunk of a RIFF/WAVE file.
    private static func pcmData(fromWAV wav: Data) -> Data? {
        let bytes = [UInt8](wav)
        guard bytes.count > 12, String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF" else { return nil }
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
            let size = Int(UInt32(bytes[offset + 4]) | UInt32(bytes[offset + 5]) << 8 | UInt32(bytes[offset + 6]) << 16 | UInt32(bytes[offset + 7]) << 24)
            let start = offset + 8
            if id == "data" { return Data(bytes[start..<min(start + size, bytes.count)]) }
            offset = start + size + (size % 2)
        }
        return nil
    }

    private static func fail(_ message: String) -> Never {
        print("SELF-TEST FAILED: \(message)")
        exit(1)
    }
}
