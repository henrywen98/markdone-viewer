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

extension MarkdownBlock {
    /// The block's text content as a plain string, for blocks that carry
    /// inline text: heading, paragraph, blockquote. `nil` for the other cases.
    public var plainText: String? {
        switch self {
        case .heading(_, let text), .paragraph(let text), .blockquote(let text):
            String(text.characters)
        case .unorderedList, .orderedList, .horizontalRule, .codeBlock, .image:
            nil
        }
    }

    /// The heading level, if this is a heading.
    public var headingLevel: Int? {
        if case .heading(let level, _) = self { return level }
        return nil
    }

    /// The list items as plain strings, if this is an unordered or ordered
    /// list.
    public var listTexts: [String]? {
        switch self {
        case .unorderedList(let items), .orderedList(let items):
            items.map { String($0.characters) }
        case .heading, .paragraph, .blockquote, .horizontalRule, .codeBlock, .image:
            nil
        }
    }

    /// The fenced code block's language hint, if any.
    public var codeLanguage: String? {
        if case .codeBlock(let language, _) = self { return language }
        return nil
    }

    /// The fenced code block's source.
    public var codeText: String? {
        if case .codeBlock(_, let code) = self { return code }
        return nil
    }

    /// The image's alt text, if any.
    public var imageAlt: String? {
        if case .image(let alt, _) = self { return alt }
        return nil
    }

    /// The image's resolved URL.
    public var imageURL: URL? {
        if case .image(_, let url) = self { return url }
        return nil
    }
}
