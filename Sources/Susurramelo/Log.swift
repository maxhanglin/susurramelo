import os

/// Unified logging. Read with:
/// `log show --last 5m --info --predicate 'subsystem == "com.susurramelo.app"'`
/// Transcript text is logged as private; the API key is never logged.
enum Log {
    static let dictation = Logger(subsystem: "com.susurramelo.app", category: "dictation")
    static let scribe = Logger(subsystem: "com.susurramelo.app", category: "scribe")
    static let insert = Logger(subsystem: "com.susurramelo.app", category: "insert")
}
