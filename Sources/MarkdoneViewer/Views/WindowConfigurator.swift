import AppKit
import SwiftUI

@MainActor
struct WindowConfigurator: NSViewRepresentable {
    let title: String
    let isEdited: Bool
    let coordinator: AppCoordinator

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            window.title = title
            window.isDocumentEdited = isEdited

            if window.delegate !== coordinator {
                window.delegate = coordinator
            }
        }
    }
}
