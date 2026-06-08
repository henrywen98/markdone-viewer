import Foundation

public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case unorderedList([AttributedString])
    case orderedList([AttributedString])
    case blockquote(AttributedString)
    case horizontalRule
    case codeBlock(language: String?, code: String)
    case image(alt: String, url: URL)
}
