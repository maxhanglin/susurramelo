import Foundation
import Testing
@testable import SusurrameloCore

@Suite struct UserDictionaryTests {
    @Test func addsWordsNewestFirst() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "Susurramelo")
        try dictionary.add(term: "ElevenLabs")
        #expect(dictionary.entries.map(\.term) == ["ElevenLabs", "Susurramelo"])
    }

    @Test func trimsAndRejectsEmptyWords() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "  Martina  ")
        #expect(dictionary.entries.first?.term == "Martina")
        #expect(throws: UserDictionary.ValidationError.empty) { try dictionary.add(term: "   ") }
    }

    @Test func rejectsCaseInsensitiveDuplicates() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "Figma")
        #expect(throws: UserDictionary.ValidationError.duplicate) { try dictionary.add(term: "figma") }
    }

    @Test func keytermsSkipLongWordsAndCapAtFifty() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "a very long phrase over twenty")
        for i in 0..<55 { try dictionary.add(term: "word\(i)") }
        let keyterms = dictionary.keyterms
        #expect(keyterms.count == 50)
        #expect(keyterms.first == "word54")
        #expect(!keyterms.contains("a very long phrase over twenty"))
        #expect(dictionary.entries.first { $0.term == "a very long phrase over twenty" }?.isSentAsKeyterm == false)
    }

    @Test func appliesReplacementsAsWholeWordsIgnoringCase() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "Susurramelo", replacing: "Susurrámelo")
        try dictionary.add(term: "Zoom", replacing: "zum")
        let text = "Abrí susurrámelo y no zumbido, zum."
        #expect(dictionary.apply(to: text) == "Abrí Susurramelo y no zumbido, Zoom.")
    }

    @Test func replacementWithRegexCharactersIsLiteral() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "C#", replacing: "c sharp")
        try dictionary.add(term: "$5", replacing: "five dollars")
        #expect(dictionary.apply(to: "I code in c sharp for five dollars") == "I code in C# for $5")
    }

    @Test func entriesWithoutReplacementLeaveTextUnchanged() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "Figma")
        #expect(dictionary.apply(to: "open figma") == "open figma")
    }

    @Test func deleteRemovesEntry() throws {
        var dictionary = UserDictionary()
        try dictionary.add(term: "Figma")
        let id = try #require(dictionary.entries.first?.id)
        dictionary.delete(id: id)
        #expect(dictionary.entries.isEmpty)
    }

    @Test func persistsAndLoads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/dictionary.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var dictionary = UserDictionary()
        try dictionary.add(term: "Susurramelo", replacing: "Susurrámelo")
        try dictionary.save(to: url)
        #expect(try UserDictionary.load(from: url) == dictionary)
        let missing = url.deletingLastPathComponent().appendingPathComponent("none.json")
        #expect(try UserDictionary.load(from: missing).entries.isEmpty)
    }

    @Test func realtimeURLEncodesPlusSoItIsNotReadAsSpace() {
        let url = ScribeProtocol.realtimeURL(languageCode: nil, keyterms: ["C++"])
        #expect(url.absoluteString.contains("keyterms=C%2B%2B"))
    }

    @Test func realtimeURLRepeatsKeytermsParameter() throws {
        let url = ScribeProtocol.realtimeURL(languageCode: "es", keyterms: ["Susurramelo", "Figma"])
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.filter { $0.name == "keyterms" }.map(\.value) == ["Susurramelo", "Figma"])
        #expect(items.contains(URLQueryItem(name: "language_code", value: "es")))
    }
}
