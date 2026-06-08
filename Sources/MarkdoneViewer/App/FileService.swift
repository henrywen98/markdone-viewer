import Foundation

/// Read/write access to a Markdown document on disk.
///
/// The coordinator depends on this protocol so that the file I/O path
/// can be exercised from tests without touching the real filesystem.
protocol FileService: Sendable {
    func read(url: URL) throws -> String
    func write(text: String, to url: URL) throws
}

/// Production file service backed by Foundation's UTF-8 I/O.
struct LocalFileService: FileService {
    func read(url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func write(text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Outcome of a "do you want to save?" prompt for an unsaved document.
enum SaveConfirmationResult: Equatable {
    /// User chose Save (and the write succeeded) or Discard. Continue.
    case proceed
    /// User chose Cancel, or the user chose Save and the write failed. Abort.
    case cancel
}
