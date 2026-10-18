import Foundation
import Security
import SusurrameloCore

/// Where the ElevenLabs API key lives: a user-only file (see `APIKeyFile`) with an unremarkable name,
/// so the app never triggers Keychain prompts. Keys saved by older versions in the Keychain are
/// moved to the file once and then removed from the Keychain. The key is cached in memory.
enum APIKeyStore {
    private static let lock = NSLock()
    private static var cached: String?

    static var file: APIKeyFile {
        APIKeyFile(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Susurramelo/.state/session.cache"))
    }

    static func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        if let key = file.read() {
            cached = key
            return key
        }
        if let legacy = LegacyKeychain.read() {
            do {
                try file.write(legacy)
                LegacyKeychain.delete()
                Log.dictation.info("Moved the API key from the Keychain to local storage")
            } catch {
                Log.dictation.error("Could not move the API key out of the Keychain: \(String(describing: error), privacy: .public)")
            }
            cached = legacy
            return legacy
        }
        return nil
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        do {
            try file.write(key)
            cached = key.trimmingCharacters(in: .whitespacesAndNewlines)
            LegacyKeychain.delete()
            return true
        } catch {
            Log.dictation.error("Could not save the API key: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}

/// The Keychain item used by versions before 0.2.0 (read once for migration, then deleted).
private enum LegacyKeychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.susurramelo.elevenlabs",
        kSecAttrAccount as String: "api-key",
    ]

    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
