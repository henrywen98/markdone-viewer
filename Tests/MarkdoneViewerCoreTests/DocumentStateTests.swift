import Foundation
import Testing
@testable import MarkdoneViewerCore

@Suite("DocumentState")
struct DocumentStateTests {
    @Test("new documents start in preview mode and are not edited")
    func initialState() {
        let state = DocumentState()

        #expect(state.fileURL == nil)
        #expect(state.text == "")
        #expect(state.lastSavedText == "")
        #expect(state.mode == .preview)
        #expect(state.previewFontSize == 16)
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "Untitled")
    }

    @Test("loading a file resets the edit marker")
    func loadFile() {
        let url = URL(fileURLWithPath: "/tmp/example.md")
        let state = DocumentState()

        state.load(text: "# Title", from: url)

        #expect(state.fileURL == url)
        #expect(state.text == "# Title")
        #expect(state.lastSavedText == "# Title")
        #expect(state.mode == .preview)
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "example.md")
    }

    @Test("editing and saving update the edit marker")
    func editAndSave() {
        let state = DocumentState()
        state.text = "changed"

        #expect(state.isEdited == true)

        state.markSaved(fileURL: URL(fileURLWithPath: "/tmp/changed.md"))

        #expect(state.lastSavedText == "changed")
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "changed.md")
    }

    @Test("mode and preview zoom commands stay bounded")
    func modeAndZoom() {
        let state = DocumentState()

        state.toggleMode()
        #expect(state.mode == .edit)

        state.toggleMode()
        #expect(state.mode == .preview)

        for _ in 0..<30 {
            state.increasePreviewFontSize()
        }
        #expect(state.previewFontSize == 30)

        for _ in 0..<40 {
            state.decreasePreviewFontSize()
        }
        #expect(state.previewFontSize == 10)

        state.resetPreviewFontSize()
        #expect(state.previewFontSize == 16)
    }
}
