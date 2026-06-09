import AppKit
import MarkdoneViewerCore
import SwiftUI

struct PreviewModeView: View {
    let text: String
    let fileURL: URL?
    let fontSize: Double

    @State private var blocks: [MarkdownBlock] = []

    var body: some View {
        PreviewTextView(blocks: blocks, fontSize: fontSize)
            .background(Color(nsColor: .textBackgroundColor))
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
        .task(id: parseKey) {
            updateBlocks()
        }
    }

    private var parseKey: ParseKey {
        ParseKey(text: text, fileURL: fileURL)
    }

    private func updateBlocks() {
        blocks = MarkdownParser.parse(text, markdownFileURL: fileURL)
    }

}

private struct ParseKey: Equatable {
    let text: String
    let fileURL: URL?
}

private struct PreviewTextView: NSViewRepresentable {
    let blocks: [MarkdownBlock]
    let fontSize: Double

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let contentWidth = scrollView.contentView.bounds.width
        textView.frame.size.width = contentWidth
        textView.textContainer?.containerSize = NSSize(
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        let maxImageWidth = max(contentWidth - 56, 100)
        textView.textStorage?.setAttributedString(
            MarkdownRichTextRenderer.render(blocks, baseFontSize: fontSize, maxImageWidth: maxImageWidth)
        )
    }
}
