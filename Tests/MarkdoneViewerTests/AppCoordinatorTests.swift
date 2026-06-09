import AppKit
import Foundation
import MarkdoneViewerCore
import Testing
@testable import MarkdoneViewer

@Suite("AppCoordinator")
@MainActor
struct AppCoordinatorTests {
    private let existingURL = URL(fileURLWithPath: "/tmp/coordinator-test.md")
    private let newURL = URL(fileURLWithPath: "/tmp/coordinator-test-new.md")

    // MARK: - save

    @Test("save writes the current text to the file URL and marks the document saved")
    func saveWritesFile() {
        let state = makeStateWithEdited(text: "hello world", fileURL: existingURL)
        let fileService = InMemoryFileService()
        var errorTitles: [String] = []
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            errorHandler: { title, _ in errorTitles.append(title) }
        )

        let result = coordinator.save()

        #expect(result == true)
        #expect(fileService.contents[existingURL] == "hello world")
        #expect(state.isEdited == false)
        #expect(errorTitles.isEmpty)
    }

    @Test("save surfaces a write error and returns false when the file service throws")
    func saveSurfacesWriteError() {
        let state = makeStateWithEdited(text: "boom", fileURL: existingURL)
        let fileService = InMemoryFileService(
            writeError: { _ in TestError("disk full") }
        )
        var errorMessages: [String] = []
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            errorHandler: { _, message in errorMessages.append(message) }
        )

        let result = coordinator.save()

        #expect(result == false)
        #expect(state.isEdited == true)
        #expect(errorMessages == ["disk full"])
    }

    @Test("save with no file URL delegates to the save panel and writes the chosen URL")
    func saveWithNoFileURLDelegatesToSavePanel() {
        let state = makeStateWithEdited(text: "first draft", fileURL: nil)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            savePanel: { _ in self.newURL }
        )

        let result = coordinator.save()

        #expect(result == true)
        #expect(state.fileURL == newURL)
        #expect(fileService.contents[newURL] == "first draft")
        #expect(state.isEdited == false)
    }

    // MARK: - saveAs

    @Test("saveAs returns false and writes nothing when the user cancels the panel")
    func saveAsCancelledPanel() {
        let state = makeStateWithEdited(text: "draft", fileURL: nil)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            savePanel: { _ in nil }
        )

        let result = coordinator.saveAs()

        #expect(result == false)
        #expect(fileService.contents.isEmpty)
        #expect(state.fileURL == nil)
    }

    // MARK: - open

    @Test("openFromPanel loads the selected file's contents into state")
    func openFromPanelLoadsFile() {
        let state = DocumentState()
        let fileService = InMemoryFileService(initial: [existingURL: "from disk"])
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            openPanel: { self.existingURL }
        )

        coordinator.openFromPanel()

        #expect(state.text == "from disk")
        #expect(state.fileURL == existingURL)
        #expect(state.isEdited == false)
    }

    @Test("openFromPanel does nothing when the user cancels the panel")
    func openFromPanelCancelled() {
        let state = DocumentState()
        state.text = "untouched"
        let fileService = InMemoryFileService(initial: [existingURL: "from disk"])
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            openPanel: { nil }
        )

        coordinator.openFromPanel()

        #expect(state.text == "untouched")
        #expect(state.fileURL == nil)
    }

    @Test("openFromPanel surfaces an error when the file service throws")
    func openFromPanelSurfacesReadError() {
        let state = DocumentState()
        let fileService = InMemoryFileService(
            readError: { _ in TestError("missing file") }
        )
        var errorMessages: [String] = []
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            openPanel: { self.existingURL },
            errorHandler: { _, message in errorMessages.append(message) }
        )

        coordinator.openFromPanel()

        #expect(state.text == "")
        #expect(state.fileURL == nil)
        #expect(errorMessages == ["missing file"])
    }

    // MARK: - confirmSaveIfNeeded

    @Test("confirmSaveIfNeeded proceeds without prompting when the document is not edited")
    func confirmProceedsWhenClean() {
        let state = DocumentState()
        let fileService = InMemoryFileService()
        var saveConfirmationCalls = 0
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in
                saveConfirmationCalls += 1
                return .cancel
            }
        )

        let result = coordinator.confirmSaveIfNeeded()

        #expect(result == .proceed)
        #expect(saveConfirmationCalls == 0)
    }

    @Test("confirmSaveIfNeeded returns cancel when the user picks cancel")
    func confirmReturnsCancel() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .cancel }
        )

        let result = coordinator.confirmSaveIfNeeded()

        #expect(result == .cancel)
        #expect(fileService.contents.isEmpty)
    }

    @Test("confirmSaveIfNeeded returns proceed when the user picks discard")
    func confirmReturnsProceedOnDiscard() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .discard }
        )

        let result = coordinator.confirmSaveIfNeeded()

        #expect(result == .proceed)
        #expect(fileService.contents.isEmpty)
    }

    @Test("confirmSaveIfNeeded returns proceed when the user picks save and the write succeeds")
    func confirmProceedsWhenSaveSucceeds() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .save }
        )

        let result = coordinator.confirmSaveIfNeeded()

        #expect(result == .proceed)
        #expect(fileService.contents[existingURL] == "draft")
        #expect(state.isEdited == false)
    }

    @Test("confirmSaveIfNeeded returns cancel when the user picks save and the write fails")
    func confirmCancelsWhenSaveFails() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService(
            writeError: { _ in TestError("disk full") }
        )
        var errorMessages: [String] = []
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .save },
            errorHandler: { _, message in errorMessages.append(message) }
        )

        let result = coordinator.confirmSaveIfNeeded()

        #expect(result == .cancel)
        #expect(state.isEdited == true)
        #expect(errorMessages == ["disk full"])
    }

    // MARK: - windowShouldClose

    @Test("windowShouldClose allows close without prompting when the document is not edited")
    func windowShouldCloseAllowsWhenClean() {
        let state = DocumentState()
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .cancel }
        )

        let result = coordinator.windowShouldClose(NSWindow())

        #expect(result == true)
    }

    @Test("windowShouldClose blocks close when the user cancels the save prompt")
    func windowShouldCloseBlocksOnCancel() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService()
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .cancel }
        )

        let result = coordinator.windowShouldClose(NSWindow())

        #expect(result == false)
    }

    // MARK: - openExternalFile

    @Test("openExternalFile does not load when the user cancels the save prompt")
    func openExternalFileBlocksOnCancel() {
        let state = makeStateWithEdited(text: "draft", fileURL: existingURL)
        let fileService = InMemoryFileService(initial: [newURL: "replacement"])
        let coordinator = makeCoordinator(
            state: state,
            fileService: fileService,
            saveConfirmation: { _ in .cancel }
        )

        coordinator.openExternalFile(newURL)

        #expect(state.text == "draft")
        #expect(state.fileURL == existingURL)
    }

    // MARK: - Helpers

    private func makeStateWithEdited(text: String, fileURL: URL?) -> DocumentState {
        let state = DocumentState()
        if let fileURL {
            state.load(text: "placeholder", from: fileURL)
        }
        state.text = text
        return state
    }

    private func makeCoordinator(
        state: DocumentState,
        fileService: FileService,
        saveConfirmation: @escaping AppCoordinator.SaveConfirmationRunner = { _ in .save },
        openPanel: @escaping AppCoordinator.OpenPanelRunner = { nil },
        savePanel: @escaping AppCoordinator.SavePanelRunner = { _ in nil },
        errorHandler: @escaping AppCoordinator.ErrorHandler = { _, _ in }
    ) -> AppCoordinator {
        AppCoordinator(
            state: state,
            fileService: fileService,
            errorHandler: errorHandler,
            saveConfirmation: saveConfirmation,
            openPanel: openPanel,
            savePanel: savePanel
        )
    }
}

private struct TestError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
