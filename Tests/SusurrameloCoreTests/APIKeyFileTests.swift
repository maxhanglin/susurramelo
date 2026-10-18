import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct APIKeyFileTests {
    private func tempFile() -> APIKeyFile {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return APIKeyFile(url: dir.appendingPathComponent("Secrets/elevenlabs-api-key"))
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    @Test func missingFileReadsAsNil() {
        #expect(tempFile().read() == nil)
    }

    @Test func roundTripsATrimmedKey() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent().deletingLastPathComponent()) }
        try file.write("  sk_test_123\n")
        #expect(file.read() == "sk_test_123")
    }

    @Test func fileIsReadableOnlyByTheUser() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent().deletingLastPathComponent()) }
        try file.write("sk_test_123")
        #expect(try permissions(file.url) == 0o600)
        #expect(try permissions(file.url.deletingLastPathComponent()) == 0o700)
    }

    @Test func overwritingKeepsRestrictedPermissions() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent().deletingLastPathComponent()) }
        try file.write("first")
        try file.write("second")
        #expect(file.read() == "second")
        #expect(try permissions(file.url) == 0o600)
    }

    @Test func fileIsExcludedFromBackups() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent().deletingLastPathComponent()) }
        try file.write("sk_test_123")
        let values = try file.url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func emptyKeyIsRejectedAndDeleteRemovesTheFile() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent().deletingLastPathComponent()) }
        #expect(throws: APIKeyFile.FileError.empty) { try file.write("   ") }
        try file.write("sk_test_123")
        try file.delete()
        #expect(file.read() == nil)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
    }
}
