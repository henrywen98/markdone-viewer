import AppKit
import MarkdoneViewerCore
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: NSObject, NSWindowDelegate {
    private let state: DocumentState

    init(state: DocumentState) {
        self.state = state
    }

    func openFromPanel() {
        guard confirmSaveIfNeeded() else {
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
        guard confirmSaveIfNeeded() else {
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
            try state.text.write(to: fileURL, atomically: true, encoding: .utf8)
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
            try state.text.write(to: url, atomically: true, encoding: .utf8)
            state.markSaved(fileURL: url)
            return true
        } catch {
            showError(title: "Save Failed", message: error.localizedDescription)
            return false
        }
    }

    func confirmSaveIfNeeded() -> Bool {
        guard state.isEdited else {
            return true
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
            return save()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmSaveIfNeeded()
    }

    private func load(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
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
