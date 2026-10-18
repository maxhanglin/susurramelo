import Foundation

/// Stores an API key in a file only the current user can read (0600 in a 0700 folder),
/// excluded from Time Machine backups. Unlike the Keychain, it never shows an access prompt,
/// but any process running as this user can read it.
public struct APIKeyFile: Sendable {
    public enum FileError: Error, Equatable {
        case empty
        case io(Int32)
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func read() -> String? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    public func write(_ key: String) throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw FileError.empty }

        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)

        // Create with 0600 from the start so the key is never briefly readable by others.
        let fd = open(url.path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw FileError.io(errno) }
        defer { close(fd) }
        guard fchmod(fd, 0o600) == 0 else { throw FileError.io(errno) }
        let bytes = Array(key.utf8)
        guard Darwin.write(fd, bytes, bytes.count) == bytes.count else { throw FileError.io(errno) }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
