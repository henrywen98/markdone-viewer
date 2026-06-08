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
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $state.mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
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
}
