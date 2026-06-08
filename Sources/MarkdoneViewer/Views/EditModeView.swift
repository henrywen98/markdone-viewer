import SwiftUI

struct EditModeView: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(16)
            .background(Color(nsColor: .textBackgroundColor))
    }
}
