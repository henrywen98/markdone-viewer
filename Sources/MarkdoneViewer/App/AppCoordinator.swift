import AppKit
import MarkdoneViewerCore
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: NSObject, NSWindowDelegate {
    typealias ErrorHandler = @MainActor (_ title: String, _ message: String) -> Void
    typealias SaveConfirmationRunner = @MainActor (_ title: String) -> SaveChoice
    typealias OpenPanelRunner = @MainActor () -> URL?
    typealias SavePanelRunner = @MainActor (_ defaultName: String) -> URL?

    private let state: DocumentState
    private let fileService: FileService
    private let errorHandler: ErrorHandler
    private let saveConfirmation: SaveConfirmationRunner
    private let openPanel: OpenPanelRunner
    private let savePanel: SavePanelRunner

    init(
        state: DocumentState,
        fileService: FileService = LocalFileService(),
        errorHandler: @escaping ErrorHandler = AppCoordinator.presentError,
        saveConfirmation: @escaping SaveConfirmationRunner = AppCoordinator.runSaveConfirmation,
        openPanel: @escaping OpenPanelRunner = AppCoordinator.runOpenPanel,
        savePanel: @escaping SavePanelRunner = AppCoordinator.runSavePanel
    ) {
        self.state = state
        self.fileService = fileService
        self.errorHandler = errorHandler
        self.saveConfirmation = saveConfirmation
        self.openPanel = openPanel
        self.savePanel = savePanel
    }

    func openFromPanel() {
        guard confirmSaveIfNeeded() == .proceed else {
            return
        }

        guard let url = openPanel() else {
            return
        }

        load(url)
    }

    func openExternalFile(_ url: URL) {
        guard confirmSaveIfNeeded() == .proceed else {
            return
        }

        load(url)
    }

    @discardableResult
    func save() -> Bool {
        guard let fileURL = state.fileURL else {
            return saveAs()
        }

        do {
            try fileService.write(text: state.text, to: fileURL)
            state.markSaved()
            return true
        } catch {
            errorHandler("Save Failed", error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        let defaultName = state.fileURL?.lastPathComponent ?? "Untitled.md"
        guard let url = savePanel(defaultName) else {
            return false
        }

        do {
            try fileService.write(text: state.text, to: url)
            state.markSaved(fileURL: url)
            return true
        } catch {
            errorHandler("Save Failed", error.localizedDescription)
            return false
        }
    }

    func confirmSaveIfNeeded() -> SaveConfirmationResult {
        guard state.isEdited else {
            return .proceed
        }

        switch saveConfirmation(state.displayTitle) {
        case .discard:
            return .proceed
        case .cancel:
            return .cancel
        case .save:
            return save() ? .proceed : .cancel
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmSaveIfNeeded() == .proceed
    }

    func copyRenderedTextToPasteboard() {
        let blocks = MarkdownParser.parse(state.text, markdownFileURL: state.fileURL)
        let renderedText = MarkdownPlainTextRenderer.render(blocks)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderedText, forType: .string)
    }

    private func load(_ url: URL) {
        do {
            let text = try fileService.read(url: url)
            state.load(text: text, from: url)
        } catch {
            errorHandler("Open Failed", error.localizedDescription)
        }
    }

    // MARK: - Default UI handlers

    private static func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private static func runSaveConfirmation(title: String) -> SaveChoice {
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to \(title)?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    private static func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = markdownContentTypes
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func runSavePanel(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static var markdownContentTypes: [UTType] {
        ["md", "markdown", "mdwn", "mdown"].compactMap {
            UTType(filenameExtension: $0)
        }
    }
}
