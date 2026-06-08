import Foundation

public enum MarkdownPlainTextRenderer {
    public static func render(_ blocks: [MarkdownBlock]) -> String {
        blocks.map(renderBlock).joined(separator: "\n\n")
    }

    private static func renderBlock(_ block: MarkdownBlock) -> String {
        switch block {
        case .heading(_, let text), .paragraph(let text), .blockquote(let text):
            String(text.characters)
        case .unorderedList(let items):
            items.map { "• \(String($0.characters))" }.joined(separator: "\n")
        case .orderedList(let items):
            items.enumerated()
                .map { index, item in "\(index + 1). \(String(item.characters))" }
                .joined(separator: "\n")
        case .horizontalRule:
            ""
        case .codeBlock(_, let code):
            code
        case .image(let alt, let url):
            alt.isEmpty ? url.lastPathComponent : alt
        }
    }
}
