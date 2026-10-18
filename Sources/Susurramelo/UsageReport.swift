import Foundation

/// `Susurramelo --usage` prints the ElevenLabs subscription's credit usage for the current period,
/// using the saved API key (never printed).
enum UsageReport {
    static func runIfRequested() {
        guard CommandLine.arguments.contains("--usage") else { return }
        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else { fail("no API key saved") }

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/user/subscription")!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { done.signal() }
            if let error { print("Request failed: \(error.localizedDescription)"); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // Error bodies describe the problem (e.g. missing key permission) and contain no secrets.
                print("HTTP \(status): \(data.map { String(decoding: $0, as: UTF8.self) } ?? "")")
                return
            }
            let used = json["character_count"] as? Int ?? -1
            let limit = json["character_limit"] as? Int ?? -1
            let reset = (json["next_character_count_reset_unix"] as? Double).map { Date(timeIntervalSince1970: $0) }
            print("tier: \(json["tier"] as? String ?? "?")")
            print("credits used: \(used) / \(limit) (remaining \(limit - used))")
            if let reset { print("resets: \(reset.formatted(date: .abbreviated, time: .shortened))") }
            if let billing = json["billing_period"] { print("billing period: \(billing)") }
            if let pricing = json["pricing_type"] ?? json["has_open_invoices"] { print("extra: \(pricing)") }
        }.resume()
        done.wait()
        exit(0)
    }

    private static func fail(_ message: String) -> Never {
        print("USAGE FAILED: \(message)")
        exit(1)
    }
}
