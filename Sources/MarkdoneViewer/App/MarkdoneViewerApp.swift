import MarkdoneViewerCore
import SwiftUI

@main
struct MarkdoneViewerApp: App {
    @State private var state: DocumentState
    @State private var coordinator: AppCoordinator
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let state = DocumentState()
        _state = State(initialValue: state)
        _coordinator = State(initialValue: AppCoordinator(state: state))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, coordinator: coordinator)
                .onAppear {
                    appDelegate.install(
                        openFileHandler: coordinator.openExternalFile(_:),
                        shouldTerminateHandler: { coordinator.confirmSaveIfNeeded() == .proceed }
                    )
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    coordinator.openFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    coordinator.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    coordinator.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Document") {
                Button("Toggle Edit/Preview") {
                    state.toggleMode()
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            CommandMenu("Preview") {
                Button("Zoom In") {
                    state.increasePreviewFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    state.decreasePreviewFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    state.resetPreviewFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
