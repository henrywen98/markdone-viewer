import AppKit
import MarkdoneViewerCore
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: NSObject, NSWindowDelegate {
    private let state: DocumentState
    private let fileService: FileService

    init(state: DocumentState, fileService: FileService = LocalFileService()) {
        self.state = state
        self.fileService = fileService
    }

    func openFromPanel() {
        guard confirmSaveIfNeeded() == .proceed else {
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = markdownContentTypes

        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
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
            showError(title: "Save Failed", message: error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = state.fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        do {
            try fileService.write(text: state.text, to: url)
            state.markSaved(fileURL: url)
            return true
        } catch {
            showError(title: "Save Failed", message: error.localizedDescription)
            return false
        }
    }

    func confirmSaveIfNeeded() -> SaveConfirmationResult {
        guard state.isEdited else {
            return .proceed
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to \(state.displayTitle)?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save() ? .proceed : .cancel
        case .alertSecondButtonReturn:
            return .proceed
        default:
            return .cancel
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
            showError(title: "Open Failed", message: error.localizedDescription)
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private var markdownContentTypes: [UTType] {
        ["md", "markdown", "mdwn", "mdown"].compactMap {
            UTType(filenameExtension: $0)
        }
    }
}
