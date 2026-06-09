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

/// In-memory file service for tests. Stores text in a dictionary keyed by
/// URL and supports scripted read/write failures so failure paths in the
/// coordinator can be exercised without touching the filesystem.
///
/// Together with `LocalFileService`, this satisfies the two-adapter test:
/// the `FileService` seam is real, not hypothetical.
///
/// A class is used so the `FileService` (non-mutating) protocol methods
/// can update the storage. `@unchecked Sendable` is safe because the
/// coordinator drives all access from `@MainActor`.
final class InMemoryFileService: FileService, @unchecked Sendable {
    private var storage: [URL: String] = [:]
    private let readErrorProvider: @Sendable (URL) -> Error?
    private let writeErrorProvider: @Sendable (URL) -> Error?

    init(
        initial: [URL: String] = [:],
        readError: @escaping @Sendable (URL) -> Error? = { _ in nil },
        writeError: @escaping @Sendable (URL) -> Error? = { _ in nil }
    ) {
        self.storage = initial
        self.readErrorProvider = readError
        self.writeErrorProvider = writeError
    }

    func read(url: URL) throws -> String {
        if let error = readErrorProvider(url) { throw error }
        guard let text = storage[url] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return text
    }

    func write(text: String, to url: URL) throws {
        if let error = writeErrorProvider(url) { throw error }
        storage[url] = text
    }

    /// Inspect the stored contents. Intended for test assertions.
    var contents: [URL: String] { storage }
}

/// Outcome of a "do you want to save?" prompt for an unsaved document.
enum SaveConfirmationResult: Equatable {
    /// User chose Save (and the write succeeded) or Discard. Continue.
    case proceed
    /// User chose Cancel, or the user chose Save and the write failed. Abort.
    case cancel
}

/// A user's response to the "do you want to save?" prompt, before the
/// coordinator maps it into a `SaveConfirmationResult`. Splitting these
/// keeps the mapping logic (save+write-fail ⇒ cancel) in the coordinator
/// where it can be tested without AppKit.
enum SaveChoice: Equatable {
    case save
    case discard
    case cancel
}
