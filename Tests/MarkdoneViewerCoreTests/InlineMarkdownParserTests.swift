import Foundation
import Testing
@testable import MarkdoneViewerCore

@Suite("InlineMarkdownParser")
struct InlineMarkdownParserTests {
    @Test("plain text remains plain")
    func plainText() {
        let result = InlineMarkdownParser.parse("Hello 世界")

        #expect(String(result.characters) == "Hello 世界")
    }

    @Test("bold, italic, and inline code markers are removed")
    func inlineMarkers() {
        let result = InlineMarkdownParser.parse("A **bold** *italic* `code`")

        #expect(String(result.characters) == "A bold italic code")
        #expect(hasIntent(result, .stronglyEmphasized))
        #expect(hasIntent(result, .emphasized))
        #expect(hasIntent(result, .code))
    }

    @Test("links expose URL attributes")
    func links() {
        let result = InlineMarkdownParser.parse("Read [site](https://example.com)")

        #expect(String(result.characters) == "Read site")
        #expect(hasLink(result, URL(string: "https://example.com")!))
    }

    @Test("inline runs expose styling traits for preview rendering")
    func inlineRuns() {
        let source = InlineMarkdownParser.parse("A **bold** *italic* `code` [site](https://example.com)")
        let runs = InlineMarkdownRun.runs(in: source)

        #expect(runs.map(\.text) == ["A ", "bold", " ", "italic", " ", "code", " ", "site"])
        #expect(runs[1].traits == [.strong])
        #expect(runs[3].traits == [.emphasis])
        #expect(runs[5].traits == [.code])
        #expect(runs[7].link == URL(string: "https://example.com")!)
    }

    @Test("malformed inline syntax renders as literal text")
    func malformedSyntax() {
        let result = InlineMarkdownParser.parse("Broken **bold and [link](not a url")

        #expect(String(result.characters) == "Broken **bold and [link](not a url")
    }

    @Test("malformed strong delimiter remains literal")
    func malformedStrongDelimiter() {
        let result = InlineMarkdownParser.parse("Broken **bold*")

        #expect(String(result.characters) == "Broken **bold*")
        #expect(!hasIntent(result, .emphasized))
        #expect(!hasIntent(result, .stronglyEmphasized))
    }

    @Test("complete links without URL schemes remain literal")
    func completeLinkWithoutURLScheme() {
        let result = InlineMarkdownParser.parse("[**x**](relative)")

        #expect(String(result.characters) == "[**x**](relative)")
        #expect(!hasIntent(result, .stronglyEmphasized))
        #expect(!hasLink(result, URL(string: "relative")!))
    }

    @Test("incomplete links remain literal")
    func incompleteLink() {
        let result = InlineMarkdownParser.parse("[**x**](relative")

        #expect(String(result.characters) == "[**x**](relative")
        #expect(!hasIntent(result, .stronglyEmphasized))
    }

    private func hasIntent(_ value: AttributedString, _ intent: InlinePresentationIntent) -> Bool {
        value.runs.contains { run in
            run.inlinePresentationIntent?.contains(intent) == true
        }
    }

    private func hasLink(_ value: AttributedString, _ url: URL) -> Bool {
        value.runs.contains { run in
            run.link == url
        }
    }
}
