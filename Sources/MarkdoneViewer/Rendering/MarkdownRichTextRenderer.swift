import AppKit
import MarkdoneViewerCore

/// Renders parsed Markdown blocks as a single `NSAttributedString` suitable
/// for the preview pane.
///
/// The renderer concentrates every AppKit-bound styling decision — heading
/// scale, list bullets, image attachments, link underlining, code-block
/// monospace font, blockquote glyph — that previously lived inside
/// `PreviewTextView`. Pulling it out gives the SwiftUI view a smaller
/// surface to maintain and lets the rendering be tested in isolation.
enum MarkdownRichTextRenderer {
    /// Render `blocks` as one attributed string, with consecutive blocks
    /// separated by blank lines.
    ///
    /// - Parameters:
    ///   - blocks: Parsed Markdown blocks, in document order.
    ///   - baseFontSize: Body-text font size in points. Headings, list
    ///     items, and blockquotes are sized relative to this value.
    ///   - maxImageWidth: Maximum width in points for embedded images.
    ///     Images wider than this are scaled down to fit.
    static func render(
        _ blocks: [MarkdownBlock],
        baseFontSize: Double,
        maxImageWidth: CGFloat
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n\n"))
            }
            result.append(attributedBlock(block, baseFontSize: baseFontSize, maxImageWidth: maxImageWidth))
        }

        return result
    }

    // MARK: - Block dispatch

    private static func attributedBlock(
        _ block: MarkdownBlock,
        baseFontSize: Double,
        maxImageWidth: CGFloat
    ) -> NSAttributedString {
        switch block {
        case .heading(let level, let text):
            return attributedInline(
                text,
                fontSize: headingFontSize(for: level, base: baseFontSize),
                weight: .bold
            )
        case .paragraph(let text):
            return attributedInline(text, fontSize: baseFontSize)
        case .unorderedList(let items):
            return joined(items.map { item in
                let line = NSMutableAttributedString(string: "• ", attributes: attributes(fontSize: baseFontSize))
                line.append(attributedInline(item, fontSize: baseFontSize))
                return line
            }, separator: "\n")
        case .orderedList(let items):
            return joined(items.enumerated().map { index, item in
                let line = NSMutableAttributedString(
                    string: "\(index + 1). ",
                    attributes: attributes(fontSize: baseFontSize)
                )
                line.append(attributedInline(item, fontSize: baseFontSize))
                return line
            }, separator: "\n")
        case .blockquote(let text):
            let quote = NSMutableAttributedString(
                string: "▌ ",
                attributes: attributes(fontSize: baseFontSize, color: .secondaryLabelColor)
            )
            quote.append(attributedInline(text, fontSize: baseFontSize, color: .secondaryLabelColor))
            return quote
        case .horizontalRule:
            return NSAttributedString(
                string: "────────",
                attributes: attributes(fontSize: baseFontSize, color: .separatorColor)
            )
        case .codeBlock(_, let code):
            return NSAttributedString(
                string: code,
                attributes: attributes(fontSize: baseFontSize - 1, isMonospaced: true)
            )
        case .image(let alt, let url):
            return attributedImage(alt: alt, url: url, fontSize: baseFontSize, maxWidth: maxImageWidth)
        }
    }

    // MARK: - Heading scale

    private static func headingFontSize(for level: Int, base: Double) -> Double {
        switch level {
        case 1: base + 14
        case 2: base + 10
        case 3: base + 7
        case 4: base + 4
        case 5: base + 2
        default: base
        }
    }

    // MARK: - Inline runs

    private static func attributedInline(
        _ value: AttributedString,
        fontSize: Double,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in InlineMarkdownRun.runs(in: value) {
            let runWeight: NSFont.Weight = run.traits.contains(.strong) ? .bold : weight
            let isMonospaced = run.traits.contains(.code)
            let runColor: NSColor = run.link == nil ? color : .linkColor
            let attributed = NSMutableAttributedString(
                string: run.text,
                attributes: attributes(
                    fontSize: fontSize,
                    weight: runWeight,
                    isMonospaced: isMonospaced,
                    color: runColor
                )
            )
            if run.traits.contains(.emphasis) {
                attributed.addAttribute(
                    .obliqueness,
                    value: 0.2,
                    range: NSRange(location: 0, length: attributed.length)
                )
            }
            if let link = run.link {
                attributed.addAttribute(.link, value: link, range: NSRange(location: 0, length: attributed.length))
                attributed.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: 0, length: attributed.length)
                )
            }
            result.append(attributed)
        }
        return result
    }

    // MARK: - Image

    private static func attributedImage(
        alt: String,
        url: URL,
        fontSize: Double,
        maxWidth: CGFloat
    ) -> NSAttributedString {
        guard let image = NSImage(contentsOf: url) else {
            return NSAttributedString(
                string: alt.isEmpty ? url.lastPathComponent : alt,
                attributes: attributes(
                    fontSize: fontSize,
                    isMonospaced: true,
                    color: .secondaryLabelColor
                )
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

    // MARK: - Helpers

    private static func joined(_ values: [NSAttributedString], separator: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, value) in values.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: separator))
            }
            result.append(value)
        }
        return result
    }

    private static func attributes(
        fontSize: Double,
        weight: NSFont.Weight = .regular,
        isMonospaced: Bool = false,
        color: NSColor = .labelColor
    ) -> [NSAttributedString.Key: Any] {
        let font: NSFont
        if isMonospaced {
            font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        } else {
            font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        }
        return [
            .font: font,
            .foregroundColor: color
        ]
    }
}
