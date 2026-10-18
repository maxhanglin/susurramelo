import Foundation

/// Builds the full transcript of one dictation. The server may commit several segments during a
/// long recording (not only the one we request on release), so every committed segment is kept.
public struct TranscriptAssembler: Sendable {
    private var segments: [String] = []
    private var pendingPartial = ""

    public init() {}

    public mutating func partial(_ text: String) {
        pendingPartial = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func committed(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { segments.append(trimmed) }
        pendingPartial = ""
    }

    /// All committed segments, in order.
    public var committedText: String {
        segments.joined(separator: " ")
    }

    /// Committed segments plus any not-yet-committed partial (used when the final commit times out).
    public var bestEffortText: String {
        (pendingPartial.isEmpty ? segments : segments + [pendingPartial]).joined(separator: " ")
    }
}
