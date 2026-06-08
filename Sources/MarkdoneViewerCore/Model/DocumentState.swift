import Foundation
import Observation

@Observable
public final class DocumentState {
    public static let defaultPreviewFontSize: Double = 16
    public static let minPreviewFontSize: Double = 10
    public static let maxPreviewFontSize: Double = 30

    public var fileURL: URL?
    public var text: String
    public var lastSavedText: String
    public var mode: Mode
    public var previewFontSize: Double

    public init(
        fileURL: URL? = nil,
        text: String = "",
        lastSavedText: String = "",
        mode: Mode = .preview,
        previewFontSize: Double = DocumentState.defaultPreviewFontSize
    ) {
        self.fileURL = fileURL
        self.text = text
        self.lastSavedText = lastSavedText
        self.mode = mode
        self.previewFontSize = previewFontSize
    }

    public var isEdited: Bool {
        text != lastSavedText
    }

    public var displayTitle: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    public func load(text: String, from fileURL: URL) {
        self.fileURL = fileURL
        self.text = text
        self.lastSavedText = text
        self.mode = .preview
    }

    public func markSaved(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        }
        lastSavedText = text
    }

    public func toggleMode() {
        mode = mode == .edit ? .preview : .edit
    }

    public func increasePreviewFontSize() {
        previewFontSize = min(previewFontSize + 1, Self.maxPreviewFontSize)
    }

    public func decreasePreviewFontSize() {
        previewFontSize = max(previewFontSize - 1, Self.minPreviewFontSize)
    }

    public func resetPreviewFontSize() {
        previewFontSize = Self.defaultPreviewFontSize
    }
}

public enum Mode: String, CaseIterable, Identifiable, Equatable {
    case edit
    case preview

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .edit:
            "Edit"
        case .preview:
            "Preview"
        }
    }
}
