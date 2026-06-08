import Foundation
import Testing
@testable import MarkdoneViewerCore

@Suite("MarkdownPlainTextRenderer")
struct MarkdownPlainTextRendererTests {
    @Test("renders blocks as copyable plain text")
    func rendersBlocksAsCopyablePlainText() {
        let blocks = MarkdownParser.parse("""
        # Title

        Paragraph with **bold**.

        - one
        - two

        > quoted

        ```swift
        let value = 1
        ```
        """)

        #expect(MarkdownPlainTextRenderer.render(blocks) == """
        Title

        Paragraph with bold.

        • one
        • two

        quoted

        let value = 1
        """)
    }
}
