import Foundation
import Testing
@testable import MarkdoneViewerCore

@Suite("MarkdownParser")
struct MarkdownParserTests {
    @Test("empty and blank input produce no blocks")
    func emptyInput() {
        #expect(MarkdownParser.parse("").isEmpty)
        #expect(MarkdownParser.parse("\n\n  \n").isEmpty)
    }

    @Test("headings parse from level one through six")
    func headings() {
        let blocks = MarkdownParser.parse("""
        # Level 1
        ## Level 2
        ### Level 3
        #### Level 4
        ##### Level 5
        ###### Level 6
        """)

        #expect(blocks.count == 6)
        for (index, block) in blocks.enumerated() {
            let level = index + 1
            #expect(block.plainText == "Level \(level)")
            #expect(block.headingLevel == level)
        }
    }

    @Test("paragraph lines join until a blank line")
    func paragraphs() throws {
        let blocks = MarkdownParser.parse("Hello\nworld\n\nNext")

        #expect(blocks.count == 2)
        #expect(blocks[0].plainText == "Hello world")
        #expect(blocks[1].plainText == "Next")
    }

    @Test("CRLF line endings do not create synthetic blank lines")
    func crlfLineEndings() throws {
        let blocks = MarkdownParser.parse("Hello\r\nworld\r\n\r\n- one\r\n- two\r\n\r\n```swift\r\nlet x = 1\r\n\r\nprint(x)\r\n```")

        #expect(blocks.count == 3)
        #expect(blocks[0].plainText == "Hello world")
        #expect(blocks[1].listTexts == ["one", "two"])
        let codeBlock = try #require(blocks.last)
        #expect(codeBlock.codeLanguage == "swift")
        #expect(codeBlock.codeText == "let x = 1\n\nprint(x)")
    }

    @Test("flat unordered and ordered lists group consecutive items")
    func lists() throws {
        let blocks = MarkdownParser.parse("- one\n* two\n\n1. first\n2. second")

        #expect(blocks.count == 2)
        #expect(blocks[0].listTexts == ["one", "two"])
        #expect(blocks[1].listTexts == ["first", "second"])
    }

    @Test("blockquotes and horizontal rules parse as blocks")
    func quoteAndRule() throws {
        let blocks = MarkdownParser.parse("> hello\n> 世界\n\n---\n***")

        #expect(blocks.count == 3)
        #expect(blocks[0].plainText == "hello 世界")
        #expect(blocks[1] == .horizontalRule)
        #expect(blocks[2] == .horizontalRule)
    }

    @Test("fenced code keeps blank lines and language")
    func fencedCode() throws {
        let blocks = MarkdownParser.parse("```swift\nlet x = 1\n\nprint(x)\n```")

        let block = try #require(blocks.first)
        #expect(block.codeLanguage == "swift")
        #expect(block.codeText == "let x = 1\n\nprint(x)")
    }

    @Test("local images resolve relative to the markdown file")
    func imageResolution() throws {
        let markdownURL = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let blocks = MarkdownParser.parse("![Alt](images/pic.png)", markdownFileURL: markdownURL)

        let block = try #require(blocks.first)
        #expect(block.imageAlt == "Alt")
        #expect(block.imageURL == URL(fileURLWithPath: "/tmp/docs/images/pic.png"))
    }

    @Test("remote images render as literal paragraphs")
    func remoteImagesRemainText() throws {
        let blocks = MarkdownParser.parse("![Alt](https://example.com/pic.png)")

        #expect(blocks.count == 1)
        #expect(blocks[0].plainText == "![Alt](https://example.com/pic.png)")
    }

    @Test("remote images remain separate literal paragraphs between text blocks")
    func remoteImageParagraphBoundary() throws {
        let blocks = MarkdownParser.parse("Intro\n![Alt](https://example.com/a.png)\nAfter")

        #expect(blocks.count == 3)
        let first = try #require(blocks.first)
        let second = try #require(blocks.dropFirst().first)
        let third = try #require(blocks.dropFirst(2).first)
        #expect(first.plainText == "Intro")
        #expect(second.plainText == "![Alt](https://example.com/a.png)")
        #expect(third.plainText == "After")
    }

    @Test("parser handles a 100KB document inside the v1 budget")
    func performanceBudget() {
        let source = Array(repeating: "Paragraph with **bold** and [link](https://example.com).", count: 1800)
            .joined(separator: "\n\n")
        let start = ContinuousClock.now
        let blocks = MarkdownParser.parse(source)
        let duration = start.duration(to: .now)
        let enforceReleaseBudget = ProcessInfo.processInfo.environment["MARKDONE_PERF_TEST"] == "1"

        #expect(blocks.count == 1800)
        if enforceReleaseBudget {
            #expect(duration < .milliseconds(100))
        } else {
            #expect(duration < .seconds(1))
        }
    }
}

private extension MarkdownBlock {
    var plainText: String? {
        switch self {
        case .heading(_, let text), .paragraph(let text), .blockquote(let text):
            String(text.characters)
        default:
            nil
        }
    }

    var headingLevel: Int? {
        if case .heading(let level, _) = self {
            level
        } else {
            nil
        }
    }

    var listTexts: [String]? {
        switch self {
        case .unorderedList(let items), .orderedList(let items):
            items.map { String($0.characters) }
        default:
            nil
        }
    }

    var codeLanguage: String? {
        if case .codeBlock(let language, _) = self {
            language
        } else {
            nil
        }
    }

    var codeText: String? {
        if case .codeBlock(_, let code) = self {
            code
        } else {
            nil
        }
    }

    var imageAlt: String? {
        if case .image(let alt, _) = self {
            alt
        } else {
            nil
        }
    }

    var imageURL: URL? {
        if case .image(_, let url) = self {
            url
        } else {
            nil
        }
    }
}
