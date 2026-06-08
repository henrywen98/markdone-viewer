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
        textView.textStorage?.setAttributedString(attributedString(maxImageWidth: maxImageWidth))
    }

    private func attributedString(maxImageWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n\n"))
            }
            result.append(attributedBlock(block, maxImageWidth: maxImageWidth))
        }

        return result
    }

    private func attributedBlock(_ block: MarkdownBlock, maxImageWidth: CGFloat) -> NSAttributedString {
        switch block {
        case .heading(let level, let text):
            return attributedInline(text, fontSize: headingFontSize(for: level), weight: .bold)
        case .paragraph(let text):
            return attributedInline(text, fontSize: fontSize)
        case .unorderedList(let items):
            return joined(items.map { item in
                let line = NSMutableAttributedString(string: "• ", attributes: attributes(fontSize: fontSize))
                line.append(attributedInline(item, fontSize: fontSize))
                return line
            }, separator: "\n")
        case .orderedList(let items):
            return joined(items.enumerated().map { index, item in
                let line = NSMutableAttributedString(string: "\(index + 1). ", attributes: attributes(fontSize: fontSize))
                line.append(attributedInline(item, fontSize: fontSize))
                return line
            }, separator: "\n")
        case .blockquote(let text):
            let quote = NSMutableAttributedString(string: "▌ ", attributes: attributes(fontSize: fontSize, color: .secondaryLabelColor))
            quote.append(attributedInline(text, fontSize: fontSize, color: .secondaryLabelColor))
            return quote
        case .horizontalRule:
            return NSAttributedString(string: "────────", attributes: attributes(fontSize: fontSize, color: .separatorColor))
        case .codeBlock(_, let code):
            return NSAttributedString(string: code, attributes: attributes(fontSize: fontSize - 1, design: .monospaced))
        case .image(let alt, let url):
            return attributedImage(alt: alt, url: url, maxWidth: maxImageWidth)
        }
    }

    private func attributedImage(alt: String, url: URL, maxWidth: CGFloat) -> NSAttributedString {
        guard let image = NSImage(contentsOf: url) else {
            return NSAttributedString(
                string: alt.isEmpty ? url.lastPathComponent : alt,
                attributes: attributes(fontSize: fontSize, design: .monospaced, color: .secondaryLabelColor)
            )
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let scale = min(1, maxWidth / max(image.size.width, 1))
        attachment.bounds = NSRect(
            x: 0,
            y: 0,
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        return NSAttributedString(attachment: attachment)
    }

    private func attributedInline(
        _ value: AttributedString,
        fontSize: Double,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in InlineMarkdownRun.runs(in: value) {
            let runWeight: NSFont.Weight = run.traits.contains(.strong) ? .bold : weight
            let design: Font.Design = run.traits.contains(.code) ? .monospaced : .default
            let runColor = run.link == nil ? color : .linkColor
            let attributed = NSMutableAttributedString(
                string: run.text,
                attributes: attributes(fontSize: fontSize, weight: runWeight, design: design, color: runColor)
            )
            if run.traits.contains(.emphasis) {
                attributed.addAttribute(.obliqueness, value: 0.2, range: NSRange(location: 0, length: attributed.length))
            }
            if let link = run.link {
                attributed.addAttribute(.link, value: link, range: NSRange(location: 0, length: attributed.length))
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributed.length))
            }
            result.append(attributed)
        }
        return result
    }

    private func joined(_ values: [NSAttributedString], separator: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, value) in values.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: separator))
            }
            result.append(value)
        }
        return result
    }

    private func attributes(
        fontSize: Double,
        weight: NSFont.Weight = .regular,
        design: Font.Design = .default,
        color: NSColor = .labelColor
    ) -> [NSAttributedString.Key: Any] {
        let font: NSFont
        if design == .monospaced {
            font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        } else {
            font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        }

        return [
            .font: font,
            .foregroundColor: color
        ]
    }

    private func headingFontSize(for level: Int) -> Double {
        switch level {
        case 1: fontSize + 14
        case 2: fontSize + 10
        case 3: fontSize + 7
        case 4: fontSize + 4
        case 5: fontSize + 2
        default: fontSize
        }
    }
}
