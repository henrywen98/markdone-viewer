import AppKit
import MarkdoneViewerCore
import Testing
@testable import MarkdoneViewer

@Suite("MarkdownRichTextRenderer")
struct MarkdownRichTextRendererTests {
    private let baseFontSize: Double = 16
    private let maxImageWidth: CGFloat = 500

    @Test("headings render in bold at scaled font sizes")
    func headings() throws {
        let blocks = MarkdownParser.parse("""
        # H1
        ## H2
        ### H3
        """)

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let expectedSizes: [(label: String, size: Double)] = [
            ("H1", baseFontSize + 14),
            ("H2", baseFontSize + 10),
            ("H3", baseFontSize + 7)
        ]
        for entry in expectedSizes {
            let font = try #require(fontForSubstring(entry.label, in: rendered))
            #expect(
                abs(font.pointSize - entry.size) < 0.5,
                "label \(entry.label) expected size ~\(entry.size) got \(font.pointSize)"
            )
            #expect(
                font.fontDescriptor.symbolicTraits.contains(.bold),
                "label \(entry.label) should be bold"
            )
        }
    }

    @Test("paragraphs render at the base font size in label color")
    func paragraphs() throws {
        let blocks = MarkdownParser.parse("hello world")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let font = try #require(fontForSubstring("hello", in: rendered))
        #expect(abs(font.pointSize - baseFontSize) < 0.5)
        #expect(!font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    @Test("unordered list items are prefixed with a bullet glyph")
    func unorderedList() {
        let blocks = MarkdownParser.parse("- one\n- two")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("• one"))
        #expect(rendered.string.contains("• two"))
    }

    @Test("ordered list items are numbered sequentially")
    func orderedList() {
        let blocks = MarkdownParser.parse("1. one\n2. two\n3. three")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("1. one"))
        #expect(rendered.string.contains("2. two"))
        #expect(rendered.string.contains("3. three"))
    }

    @Test("horizontal rules render as a separator glyph in the separator color")
    func horizontalRule() {
        let blocks = MarkdownParser.parse("---")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("────────"))
    }

    @Test("fenced code blocks keep their content and use a monospaced font")
    func codeBlock() throws {
        let blocks = MarkdownParser.parse("```swift\nlet x = 1\n```")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("let x = 1"))
        let font = try #require(fontForSubstring("let x = 1", in: rendered))
        #expect(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test("blockquotes carry a prefix glyph and use the secondary label color")
    func blockquote() {
        let blocks = MarkdownParser.parse("> quoted")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("▌"))
        #expect(rendered.string.contains("quoted"))
    }

    @Test("inline bold runs use a bold font")
    func boldRun() throws {
        let blocks = MarkdownParser.parse("A **bold** B")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let font = try #require(fontForSubstring("bold", in: rendered))
        #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    @Test("inline italic runs carry an obliqueness attribute")
    func italicRun() throws {
        let blocks = MarkdownParser.parse("An *italic* word")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let range = try #require(rangeOfSubstring("italic", in: rendered))
        let obliqueness = try #require(
            rendered.attribute(.obliqueness, at: range.location, effectiveRange: nil) as? Double
        )
        #expect(obliqueness > 0)
    }

    @Test("inline code runs use a monospaced font")
    func inlineCodeRun() throws {
        let blocks = MarkdownParser.parse("Some `code` here")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let font = try #require(fontForSubstring("code", in: rendered))
        #expect(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test("inline links carry link and underline attributes")
    func linkRun() throws {
        let url = URL(string: "https://example.com")!
        let blocks = MarkdownParser.parse("Read [site](\(url.absoluteString))")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        let range = try #require(rangeOfSubstring("site", in: rendered))
        let linkAttr = try #require(
            rendered.attribute(.link, at: range.location, effectiveRange: nil) as? URL
        )
        #expect(linkAttr == url)
        let underline = try #require(
            rendered.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int
        )
        #expect(underline == NSUnderlineStyle.single.rawValue)
    }

    @Test("images with an unresolvable URL fall back to the alt text")
    func imageFallbackWithAlt() {
        let blocks: [MarkdownBlock] = [
            .image(alt: "Diagram", url: URL(fileURLWithPath: "/nonexistent-diagram.png"))
        ]

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("Diagram"))
    }

    @Test("images with an empty alt fall back to the file name")
    func imageFallbackEmptyAlt() {
        let blocks: [MarkdownBlock] = [
            .image(alt: "", url: URL(fileURLWithPath: "/nonexistent-diagram.png"))
        ]

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("nonexistent-diagram.png"))
    }

    @Test("consecutive blocks are separated by a blank line")
    func blockSeparators() {
        let blocks = MarkdownParser.parse("# Title\n\nA paragraph")

        let rendered = MarkdownRichTextRenderer.render(
            blocks,
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.contains("Title\n\nA paragraph"))
    }

    @Test("empty input produces an empty attributed string")
    func emptyInput() {
        let rendered = MarkdownRichTextRenderer.render(
            [],
            baseFontSize: baseFontSize,
            maxImageWidth: maxImageWidth
        )

        #expect(rendered.string.isEmpty)
    }

    // MARK: - Helpers

    private func fontForSubstring(_ substring: String, in attributed: NSAttributedString) -> NSFont? {
        guard let range = rangeOfSubstring(substring, in: attributed) else {
            return nil
        }
        return attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
    }

    private func rangeOfSubstring(_ substring: String, in attributed: NSAttributedString) -> NSRange? {
        let storage = attributed.string as NSString
        let found = storage.range(of: substring)
        return found.location == NSNotFound ? nil : found
    }
}
