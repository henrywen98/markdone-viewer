import MarkdoneViewerCore
import SwiftUI

struct ContentView: View {
    @Bindable var state: DocumentState
    let coordinator: AppCoordinator

    var body: some View {
        Group {
            switch state.mode {
            case .edit:
                EditModeView(text: $state.text)
            case .preview:
                PreviewModeView(
                    text: state.text,
                    fileURL: state.fileURL,
                    fontSize: state.previewFontSize
                )
            }
        }
        .frame(minWidth: 820, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.toggleMode()
                } label: {
                    Label(modeToggleTitle, systemImage: modeToggleSystemImage)
                }
                .help("Switch to \(modeToggleTitle)")
            }
        }
        .background(
            WindowConfigurator(
                title: state.displayTitle,
                isEdited: state.isEdited,
                coordinator: coordinator
            )
        )
    }

    private var modeToggleTitle: String {
        state.mode == .preview ? "Edit" : "Preview"
    }

    private var modeToggleSystemImage: String {
        state.mode == .preview ? "pencil" : "doc.text"
    }
}
