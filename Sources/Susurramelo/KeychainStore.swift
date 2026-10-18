import Foundation
import Security

/// Stores the ElevenLabs API key as a generic password in the user's login Keychain.
/// The key is read from the Keychain at most once per launch and then kept in memory, so macOS
/// asks for Keychain access at most once instead of on every dictation.
enum KeychainStore {
    private static let lock = NSLock()
    private static var cached: String?
    private static let service = "com.susurramelo.elevenlabs"
    private static let account = "api-key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        cached = readFromKeychain()
        return cached
    }

    private static func readFromKeychain() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let saved = SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        lock.lock()
        cached = saved ? key : nil
        lock.unlock()
        return saved
    }
}
