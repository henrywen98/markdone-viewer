# Markdone Viewer V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS Markdown viewer/editor for one local Markdown document at a time.

**Architecture:** Use a Swift Package with a testable `MarkdoneViewerCore` library target and a SwiftUI/AppKit `MarkdoneViewer` executable target. Parser and document state live in the core target; native file panels, window coordination, commands, and rendering live in the app target.

**Tech Stack:** Swift 6.2, macOS 14+, SwiftUI, AppKit, Observation, Foundation, XCTest, Swift Package Manager.

---

## File Structure

- Create: `Package.swift` - package, executable target, core library target, test target.
- Create: `.gitignore` - local Swift/Xcode/build artifacts.
- Create: `Sources/MarkdoneViewerCore/Support/MarkdoneViewerVersion.swift` - version constant used to keep the initial core target buildable.
- Create: `Sources/MarkdoneViewerCore/Model/DocumentState.swift` - single-document state and editor/preview mode.
- Create: `Sources/MarkdoneViewerCore/Model/MarkdownBlock.swift` - parser-to-preview block enum.
- Create: `Sources/MarkdoneViewerCore/Parser/InlineMarkdownParser.swift` - inline bold, italic, code, and link parser.
- Create: `Sources/MarkdoneViewerCore/Parser/MarkdownParser.swift` - line scanner and block parser.
- Create: `Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift` - app entry, menu commands, app delegate wiring.
- Create: `Sources/MarkdoneViewer/App/AppDelegate.swift` - Finder/double-click open and quit prompt bridge.
- Create: `Sources/MarkdoneViewer/App/AppCoordinator.swift` - open/save/save-as prompts, window close coordination.
- Create: `Sources/MarkdoneViewer/Views/ContentView.swift` - mode toggle, toolbar, window state binding.
- Create: `Sources/MarkdoneViewer/Views/EditModeView.swift` - plain text editing surface.
- Create: `Sources/MarkdoneViewer/Views/PreviewModeView.swift` - rendered Markdown preview.
- Create: `Sources/MarkdoneViewer/Views/WindowConfigurator.swift` - title, edited indicator, close delegate.
- Create: `Resources/Info.plist` - app bundle metadata and Markdown file association.
- Create: `Scripts/build-app.sh` - CLI app bundle assembly for local testing.
- Create: `Tests/MarkdoneViewerCoreTests/DocumentStateTests.swift` - state behavior tests.
- Create: `Tests/MarkdoneViewerCoreTests/InlineMarkdownParserTests.swift` - inline parser tests.
- Create: `Tests/MarkdoneViewerCoreTests/MarkdownParserTests.swift` - block parser tests.

Xcode 26 opens `Package.swift` directly as a native project. This plan uses SwiftPM plus a deterministic `.app` bundling script instead of committing generated Xcode project metadata in the first implementation pass.

---

### Task 1: Buildable Swift Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/MarkdoneViewerCore/Support/MarkdoneViewerVersion.swift`
- Create: `Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift`

- [ ] **Step 1: Create the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "markdone-viewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MarkdoneViewerCore",
            targets: ["MarkdoneViewerCore"]
        ),
        .executable(
            name: "MarkdoneViewer",
            targets: ["MarkdoneViewer"]
        )
    ],
    targets: [
        .target(
            name: "MarkdoneViewerCore",
            path: "Sources/MarkdoneViewerCore"
        ),
        .executableTarget(
            name: "MarkdoneViewer",
            dependencies: ["MarkdoneViewerCore"],
            path: "Sources/MarkdoneViewer"
        ),
        .testTarget(
            name: "MarkdoneViewerCoreTests",
            dependencies: ["MarkdoneViewerCore"],
            path: "Tests/MarkdoneViewerCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Create the ignore file**

Create `.gitignore`:

```gitignore
.DS_Store
.build/
build/
DerivedData/
*.xcuserstate
*.xcuserdata/
*.moved-aside
```

- [ ] **Step 3: Create the initial core source file**

Create `Sources/MarkdoneViewerCore/Support/MarkdoneViewerVersion.swift`:

```swift
import Foundation

public enum MarkdoneViewerVersion {
    public static let value = "0.1.0"
}
```

- [ ] **Step 4: Create the initial app entry**

Create `Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift`:

```swift
import MarkdoneViewerCore
import SwiftUI

@main
struct MarkdoneViewerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Untitled")
                .font(.system(.body))
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
```

- [ ] **Step 5: Verify the scaffold builds**

Run:

```bash
swift test
swift build
```

Expected: both commands exit with status `0`. `swift test` reports that the package builds even though no tests exist yet.

- [ ] **Step 6: Commit the scaffold**

```bash
git add Package.swift .gitignore Sources/MarkdoneViewerCore/Support/MarkdoneViewerVersion.swift Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift
git commit -m "chore: scaffold markdone viewer package"
```

---

### Task 2: Document State And Block Model

**Files:**
- Create: `Tests/MarkdoneViewerCoreTests/DocumentStateTests.swift`
- Create: `Sources/MarkdoneViewerCore/Model/DocumentState.swift`
- Create: `Sources/MarkdoneViewerCore/Model/MarkdownBlock.swift`

- [ ] **Step 1: Write failing document state tests**

Create `Tests/MarkdoneViewerCoreTests/DocumentStateTests.swift`:

```swift
import Foundation
import Testing
@testable import MarkdoneViewerCore

@Suite("DocumentState")
struct DocumentStateTests {
    @Test("new documents start in preview mode and are not edited")
    func initialState() {
        let state = DocumentState()

        #expect(state.fileURL == nil)
        #expect(state.text == "")
        #expect(state.lastSavedText == "")
        #expect(state.mode == .preview)
        #expect(state.previewFontSize == 16)
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "Untitled")
    }

    @Test("loading a file resets the edit marker")
    func loadFile() {
        let url = URL(fileURLWithPath: "/tmp/example.md")
        let state = DocumentState()

        state.load(text: "# Title", from: url)

        #expect(state.fileURL == url)
        #expect(state.text == "# Title")
        #expect(state.lastSavedText == "# Title")
        #expect(state.mode == .preview)
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "example.md")
    }

    @Test("editing and saving update the edit marker")
    func editAndSave() {
        let state = DocumentState()
        state.text = "changed"

        #expect(state.isEdited == true)

        state.markSaved(fileURL: URL(fileURLWithPath: "/tmp/changed.md"))

        #expect(state.lastSavedText == "changed")
        #expect(state.isEdited == false)
        #expect(state.displayTitle == "changed.md")
    }

    @Test("mode and preview zoom commands stay bounded")
    func modeAndZoom() {
        let state = DocumentState()

        state.toggleMode()
        #expect(state.mode == .edit)

        state.toggleMode()
        #expect(state.mode == .preview)

        for _ in 0..<30 {
            state.increasePreviewFontSize()
        }
        #expect(state.previewFontSize == 30)

        for _ in 0..<40 {
            state.decreasePreviewFontSize()
        }
        #expect(state.previewFontSize == 10)

        state.resetPreviewFontSize()
        #expect(state.previewFontSize == 16)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter DocumentStateTests
```

Expected: FAIL with errors such as `cannot find 'DocumentState' in scope`.

- [ ] **Step 3: Implement document state and block model**

Create `Sources/MarkdoneViewerCore/Model/DocumentState.swift`:

```swift
import Foundation
import Observation

@Observable
public final class DocumentState {
    public var fileURL: URL?
    public var text: String
    public var lastSavedText: String
    public var mode: Mode
    public var previewFontSize: Double

    public init(
        fileURL: URL? = nil,
        text: String = "",
        lastSavedText: String = "",
        mode: Mode = .preview,
        previewFontSize: Double = 16
    ) {
        self.fileURL = fileURL
        self.text = text
        self.lastSavedText = lastSavedText
        self.mode = mode
        self.previewFontSize = previewFontSize
    }

    public var isEdited: Bool {
        text != lastSavedText
    }

    public var displayTitle: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    public func load(text: String, from fileURL: URL) {
        self.fileURL = fileURL
        self.text = text
        self.lastSavedText = text
        self.mode = .preview
    }

    public func markSaved(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        }
        lastSavedText = text
    }

    public func toggleMode() {
        mode = mode == .edit ? .preview : .edit
    }

    public func increasePreviewFontSize() {
        previewFontSize = min(previewFontSize + 1, 30)
    }

    public func decreasePreviewFontSize() {
        previewFontSize = max(previewFontSize - 1, 10)
    }

    public func resetPreviewFontSize() {
        previewFontSize = 16
    }
}

public enum Mode: String, CaseIterable, Identifiable, Equatable {
    case edit
    case preview

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .edit:
            "Edit"
        case .preview:
            "Preview"
        }
    }
}
```

Create `Sources/MarkdoneViewerCore/Model/MarkdownBlock.swift`:

```swift
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
```

- [ ] **Step 4: Run state tests to verify pass**

Run:

```bash
swift test --filter DocumentStateTests
```

Expected: PASS.

- [ ] **Step 5: Commit the model**

```bash
git add Sources/MarkdoneViewerCore/Model Tests/MarkdoneViewerCoreTests/DocumentStateTests.swift
git commit -m "feat: add document state model"
```

---

### Task 3: Inline Markdown Parser

**Files:**
- Create: `Tests/MarkdoneViewerCoreTests/InlineMarkdownParserTests.swift`
- Create: `Sources/MarkdoneViewerCore/Parser/InlineMarkdownParser.swift`

- [ ] **Step 1: Write failing inline parser tests**

Create `Tests/MarkdoneViewerCoreTests/InlineMarkdownParserTests.swift`:

```swift
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

    @Test("malformed inline syntax renders as literal text")
    func malformedSyntax() {
        let result = InlineMarkdownParser.parse("Broken **bold and [link](not a url")

        #expect(String(result.characters) == "Broken **bold and [link](not a url")
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
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter InlineMarkdownParserTests
```

Expected: FAIL with `cannot find 'InlineMarkdownParser' in scope`.

- [ ] **Step 3: Implement inline parsing**

Create `Sources/MarkdoneViewerCore/Parser/InlineMarkdownParser.swift`:

```swift
import Foundation

public enum InlineMarkdownParser {
    public static func parse(_ source: String) -> AttributedString {
        var output = AttributedString()
        var index = source.startIndex

        while index < source.endIndex {
            if source[index...].hasPrefix("**"),
               let match = parseDelimited(
                    source,
                    openingAt: index,
                    delimiter: "**",
                    intent: .stronglyEmphasized
               ) {
                output += match.value
                index = match.nextIndex
                continue
            }

            if source[index] == "`",
               let match = parseDelimited(
                    source,
                    openingAt: index,
                    delimiter: "`",
                    intent: .code
               ) {
                output += match.value
                index = match.nextIndex
                continue
            }

            if source[index] == "[",
               let match = parseLink(source, openingAt: index) {
                output += match.value
                index = match.nextIndex
                continue
            }

            if source[index] == "*",
               !source[index...].hasPrefix("**"),
               let match = parseDelimited(
                    source,
                    openingAt: index,
                    delimiter: "*",
                    intent: .emphasized
               ) {
                output += match.value
                index = match.nextIndex
                continue
            }

            append(String(source[index]), to: &output)
            index = source.index(after: index)
        }

        return output
    }

    private static func parseDelimited(
        _ source: String,
        openingAt index: String.Index,
        delimiter: String,
        intent: InlinePresentationIntent
    ) -> (value: AttributedString, nextIndex: String.Index)? {
        let contentStart = source.index(index, offsetBy: delimiter.count)
        guard contentStart <= source.endIndex,
              let closeRange = source[contentStart...].range(of: delimiter) else {
            return nil
        }

        let content = String(source[contentStart..<closeRange.lowerBound])
        guard !content.isEmpty else {
            return nil
        }

        var value = AttributedString(content)
        value.inlinePresentationIntent = intent
        return (value, closeRange.upperBound)
    }

    private static func parseLink(
        _ source: String,
        openingAt index: String.Index
    ) -> (value: AttributedString, nextIndex: String.Index)? {
        let textStart = source.index(after: index)
        guard let closeBracket = source[textStart...].firstIndex(of: "]") else {
            return nil
        }

        let parenStart = source.index(after: closeBracket)
        guard parenStart < source.endIndex,
              source[parenStart] == "(" else {
            return nil
        }

        let urlStart = source.index(after: parenStart)
        guard let closeParen = source[urlStart...].firstIndex(of: ")") else {
            return nil
        }

        let text = String(source[textStart..<closeBracket])
        let urlText = String(source[urlStart..<closeParen])
        guard !text.isEmpty,
              let url = URL(string: urlText),
              url.scheme != nil else {
            return nil
        }

        var value = AttributedString(text)
        value.link = url
        return (value, source.index(after: closeParen))
    }

    private static func append(_ text: String, to output: inout AttributedString) {
        output += AttributedString(text)
    }
}
```

- [ ] **Step 4: Run inline parser tests**

Run:

```bash
swift test --filter InlineMarkdownParserTests
```

Expected: PASS.

- [ ] **Step 5: Commit the inline parser**

```bash
git add Sources/MarkdoneViewerCore/Parser/InlineMarkdownParser.swift Tests/MarkdoneViewerCoreTests/InlineMarkdownParserTests.swift
git commit -m "feat: parse inline markdown"
```

---

### Task 4: Block Markdown Parser

**Files:**
- Create: `Tests/MarkdoneViewerCoreTests/MarkdownParserTests.swift`
- Create: `Sources/MarkdoneViewerCore/Parser/MarkdownParser.swift`

- [ ] **Step 1: Write failing block parser tests**

Create `Tests/MarkdoneViewerCoreTests/MarkdownParserTests.swift`:

```swift
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
    func headings() throws {
        let blocks = MarkdownParser.parse("# Title\n###### Small")

        #expect(blocks.count == 2)
        let first = try #require(blocks.first)
        let last = try #require(blocks.last)
        #expect(first.plainText == "Title")
        #expect(first.headingLevel == 1)
        #expect(last.plainText == "Small")
        #expect(last.headingLevel == 6)
    }

    @Test("paragraph lines join until a blank line")
    func paragraphs() throws {
        let blocks = MarkdownParser.parse("Hello\nworld\n\nNext")

        #expect(blocks.count == 2)
        #expect(blocks[0].plainText == "Hello world")
        #expect(blocks[1].plainText == "Next")
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
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter MarkdownParserTests
```

Expected: FAIL with `cannot find 'MarkdownParser' in scope`.

- [ ] **Step 3: Implement block parsing**

Create `Sources/MarkdoneViewerCore/Parser/MarkdownParser.swift`:

```swift
import Foundation

public enum MarkdownParser {
    public static func parse(_ source: String, markdownFileURL: URL? = nil) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let result = parseCodeBlock(lines: lines, startingAt: index)
                blocks.append(result.block)
                index = result.nextIndex
                continue
            }

            if let heading = parseHeading(line) {
                blocks.append(heading)
                index += 1
                continue
            }

            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            if let image = parseImage(trimmed, markdownFileURL: markdownFileURL) {
                blocks.append(image)
                index += 1
                continue
            }

            if unorderedListItemText(line) != nil {
                let result = parseUnorderedList(lines: lines, startingAt: index)
                blocks.append(.unorderedList(result.items.map(InlineMarkdownParser.parse)))
                index = result.nextIndex
                continue
            }

            if orderedListItemText(line) != nil {
                let result = parseOrderedList(lines: lines, startingAt: index)
                blocks.append(.orderedList(result.items.map(InlineMarkdownParser.parse)))
                index = result.nextIndex
                continue
            }

            if blockquoteText(line) != nil {
                let result = parseBlockquote(lines: lines, startingAt: index)
                blocks.append(.blockquote(InlineMarkdownParser.parse(result.text)))
                index = result.nextIndex
                continue
            }

            let result = parseParagraph(lines: lines, startingAt: index)
            blocks.append(.paragraph(InlineMarkdownParser.parse(result.text)))
            index = result.nextIndex
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        var level = 0
        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }

        guard (1...6).contains(level),
              line.count > level else {
            return nil
        }

        let separatorIndex = line.index(line.startIndex, offsetBy: level)
        guard line[separatorIndex] == " " else {
            return nil
        }

        let textStart = line.index(after: separatorIndex)
        let text = String(line[textStart...])
        return .heading(level: level, text: InlineMarkdownParser.parse(text))
    }

    private static func parseCodeBlock(
        lines: [String],
        startingAt startIndex: Int
    ) -> (block: MarkdownBlock, nextIndex: Int) {
        let opening = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let rawLanguage = String(opening.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let language = rawLanguage.isEmpty ? nil : rawLanguage
        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                return (.codeBlock(language: language, code: codeLines.joined(separator: "\n")), index + 1)
            }

            codeLines.append(lines[index])
            index += 1
        }

        return (.codeBlock(language: language, code: codeLines.joined(separator: "\n")), index)
    }

    private static func parseUnorderedList(
        lines: [String],
        startingAt startIndex: Int
    ) -> (items: [String], nextIndex: Int) {
        var items: [String] = []
        var index = startIndex

        while index < lines.count, let item = unorderedListItemText(lines[index]) {
            items.append(item)
            index += 1
        }

        return (items, index)
    }

    private static func parseOrderedList(
        lines: [String],
        startingAt startIndex: Int
    ) -> (items: [String], nextIndex: Int) {
        var items: [String] = []
        var index = startIndex

        while index < lines.count, let item = orderedListItemText(lines[index]) {
            items.append(item)
            index += 1
        }

        return (items, index)
    }

    private static func parseBlockquote(
        lines: [String],
        startingAt startIndex: Int
    ) -> (text: String, nextIndex: Int) {
        var parts: [String] = []
        var index = startIndex

        while index < lines.count, let part = blockquoteText(lines[index]) {
            parts.append(part)
            index += 1
        }

        return (parts.joined(separator: " "), index)
    }

    private static func parseParagraph(
        lines: [String],
        startingAt startIndex: Int
    ) -> (text: String, nextIndex: Int) {
        var parts: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || startsBlock(trimmed, originalLine: line) {
                break
            }

            parts.append(trimmed)
            index += 1
        }

        return (parts.joined(separator: " "), index)
    }

    private static func startsBlock(_ trimmed: String, originalLine: String) -> Bool {
        trimmed.hasPrefix("```")
            || parseHeading(originalLine) != nil
            || isHorizontalRule(trimmed)
            || parseImage(trimmed, markdownFileURL: nil) != nil
            || unorderedListItemText(originalLine) != nil
            || orderedListItemText(originalLine) != nil
            || blockquoteText(originalLine) != nil
    }

    private static func isHorizontalRule(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else {
            return false
        }

        return trimmed.allSatisfy { $0 == "-" } || trimmed.allSatisfy { $0 == "*" }
    }

    private static func unorderedListItemText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }

        return nil
    }

    private static func orderedListItemText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else {
            return nil
        }

        let numberPart = trimmed[..<dotIndex]
        guard !numberPart.isEmpty,
              numberPart.allSatisfy(\.isNumber) else {
            return nil
        }

        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex,
              trimmed[afterDot] == " " else {
            return nil
        }

        let itemStart = trimmed.index(after: afterDot)
        return String(trimmed[itemStart...])
    }

    private static func blockquoteText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else {
            return nil
        }

        let content = trimmed.dropFirst()
        if content.first == " " {
            return String(content.dropFirst())
        }

        return String(content)
    }

    private static func parseImage(_ line: String, markdownFileURL: URL?) -> MarkdownBlock? {
        guard line.hasPrefix("!["),
              let closeAlt = line.firstIndex(of: "]") else {
            return nil
        }

        let parenStart = line.index(after: closeAlt)
        guard parenStart < line.endIndex,
              line[parenStart] == "(",
              line.last == ")" else {
            return nil
        }

        let altStart = line.index(line.startIndex, offsetBy: 2)
        let pathStart = line.index(after: parenStart)
        let pathEnd = line.index(before: line.endIndex)
        let alt = String(line[altStart..<closeAlt])
        let path = String(line[pathStart..<pathEnd])

        guard !path.contains("://") else {
            return nil
        }

        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else if let markdownFileURL {
            url = markdownFileURL
                .deletingLastPathComponent()
                .appendingPathComponent(path)
        } else {
            url = URL(fileURLWithPath: path)
        }

        return .image(alt: alt, url: url)
    }
}
```

- [ ] **Step 4: Run all parser tests**

Run:

```bash
swift test --filter MarkdownParserTests
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit the block parser**

```bash
git add Sources/MarkdoneViewerCore/Parser/MarkdownParser.swift Tests/MarkdoneViewerCoreTests/MarkdownParserTests.swift
git commit -m "feat: parse markdown blocks"
```

---

### Task 5: Preview Renderer

**Files:**
- Create: `Sources/MarkdoneViewer/Views/PreviewModeView.swift`

- [ ] **Step 1: Create the preview renderer**

Create `Sources/MarkdoneViewer/Views/PreviewModeView.swift`:

```swift
import AppKit
import MarkdoneViewerCore
import SwiftUI

struct PreviewModeView: View {
    let text: String
    let fileURL: URL?
    let fontSize: Double

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text, markdownFileURL: fileURL)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 940, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(.system(size: headingFontSize(for: level), weight: .bold))
                .textSelection(.enabled)

        case .paragraph(let text):
            Text(text)
                .font(.system(size: fontSize))
                .lineSpacing(3)
                .textSelection(.enabled)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(item)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: fontSize))
                }
            }
            .padding(.leading, 18)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .frame(minWidth: 24, alignment: .trailing)
                        Text(item)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: fontSize))
                }
            }
            .padding(.leading, 12)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 3)
                Text(text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)

        case .horizontalRule:
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .padding(.vertical, 8)

        case .codeBlock(_, let code):
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .image(let alt, let url):
            LocalImageView(alt: alt, url: url)
        }
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

private struct LocalImageView: View {
    let alt: String
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 820, alignment: .leading)
                .accessibilityLabel(alt)
        } else {
            Text(alt.isEmpty ? url.lastPathComponent : alt)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color(nsColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .textSelection(.enabled)
        }
    }
}
```

- [ ] **Step 2: Verify app target builds with preview code**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 3: Commit preview rendering**

```bash
git add Sources/MarkdoneViewer/Views/PreviewModeView.swift
git commit -m "feat: render markdown preview"
```

---

### Task 6: Edit Mode, Content Shell, And Window State

**Files:**
- Create: `Sources/MarkdoneViewer/Views/EditModeView.swift`
- Create: `Sources/MarkdoneViewer/Views/ContentView.swift`
- Create: `Sources/MarkdoneViewer/Views/WindowConfigurator.swift`
- Modify: `Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift`

- [ ] **Step 1: Create the edit surface**

Create `Sources/MarkdoneViewer/Views/EditModeView.swift`:

```swift
import SwiftUI

struct EditModeView: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(16)
            .background(Color(nsColor: .textBackgroundColor))
    }
}
```

- [ ] **Step 2: Create the window configurator**

Create `Sources/MarkdoneViewer/Views/WindowConfigurator.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
struct WindowConfigurator: NSViewRepresentable {
    let title: String
    let isEdited: Bool
    let coordinator: AppCoordinator

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            window.title = title
            window.isDocumentEdited = isEdited

            if window.delegate !== coordinator {
                window.delegate = coordinator
            }
        }
    }
}
```

- [ ] **Step 3: Create the content shell**

Create `Sources/MarkdoneViewer/Views/ContentView.swift`:

```swift
import MarkdoneViewerCore
import SwiftUI

struct ContentView: View {
    @Bindable var state: DocumentState
    let coordinator: AppCoordinator

    var body: some View {
        Group {
            switch state.mode {
            case .edit:
                EditModeView(text: $state.text)
            case .preview:
                PreviewModeView(
                    text: state.text,
                    fileURL: state.fileURL,
                    fontSize: state.previewFontSize
                )
            }
        }
        .frame(minWidth: 820, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $state.mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .background(
            WindowConfigurator(
                title: state.displayTitle,
                isEdited: state.isEdited,
                coordinator: coordinator
            )
        )
    }
}
```

- [ ] **Step 4: Replace the app entry with state-backed content**

Replace `Sources/MarkdoneViewer/App/MarkdoneViewerApp.swift`:

```swift
import MarkdoneViewerCore
import SwiftUI

@main
struct MarkdoneViewerApp: App {
    @State private var state: DocumentState
    @State private var coordinator: AppCoordinator
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let state = DocumentState()
        _state = State(initialValue: state)
        _coordinator = State(initialValue: AppCoordinator(state: state))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, coordinator: coordinator)
                .onAppear {
                    appDelegate.install(
                        openFileHandler: coordinator.openExternalFile(_:),
                        shouldTerminateHandler: coordinator.confirmSaveIfNeeded
                    )
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    coordinator.openFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    coordinator.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    coordinator.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Document") {
                Button("Toggle Edit/Preview") {
                    state.toggleMode()
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            CommandMenu("Preview") {
                Button("Zoom In") {
                    state.increasePreviewFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    state.decreasePreviewFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    state.resetPreviewFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
```

- [ ] **Step 5: Run build to expose missing coordinator types**

Run:

```bash
swift build
```

Expected: FAIL with errors for missing `AppCoordinator` and `AppDelegate`. Those are implemented in the next task.

- [ ] **Step 6: Commit the UI shell after Task 7 passes**

Do not commit this task before Task 7 because the app target intentionally references coordinator files that do not exist yet.

---

### Task 7: File Handling, Save Prompts, And App Delegate Bridge

**Files:**
- Create: `Sources/MarkdoneViewer/App/AppDelegate.swift`
- Create: `Sources/MarkdoneViewer/App/AppCoordinator.swift`
- Modify: files from Task 6 are committed with this task

- [ ] **Step 1: Create the AppDelegate bridge**

Create `Sources/MarkdoneViewer/App/AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var openFileHandler: ((URL) -> Void)?
    private var shouldTerminateHandler: (() -> Bool)?
    private var pendingOpenURLs: [URL] = []

    func install(
        openFileHandler: @escaping (URL) -> Void,
        shouldTerminateHandler: @escaping () -> Bool
    ) {
        self.openFileHandler = openFileHandler
        self.shouldTerminateHandler = shouldTerminateHandler

        let pending = pendingOpenURLs
        pendingOpenURLs.removeAll()
        pending.forEach(openFileHandler)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let openFileHandler else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }

        urls.prefix(1).forEach(openFileHandler)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminateHandler?() == false {
            return .terminateCancel
        }

        return .terminateNow
    }
}
```

- [ ] **Step 2: Create the coordinator**

Create `Sources/MarkdoneViewer/App/AppCoordinator.swift`:

```swift
import AppKit
import MarkdoneViewerCore
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: NSObject, NSWindowDelegate {
    private let state: DocumentState

    init(state: DocumentState) {
        self.state = state
    }

    func openFromPanel() {
        guard confirmSaveIfNeeded() else {
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = markdownContentTypes

        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    func openExternalFile(_ url: URL) {
        guard confirmSaveIfNeeded() else {
            return
        }

        load(url)
    }

    @discardableResult
    func save() -> Bool {
        guard let fileURL = state.fileURL else {
            return saveAs()
        }

        do {
            try state.text.write(to: fileURL, atomically: true, encoding: .utf8)
            state.markSaved()
            return true
        } catch {
            showError(title: "Save Failed", message: error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = markdownContentTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = state.fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        do {
            try state.text.write(to: url, atomically: true, encoding: .utf8)
            state.markSaved(fileURL: url)
            return true
        } catch {
            showError(title: "Save Failed", message: error.localizedDescription)
            return false
        }
    }

    func confirmSaveIfNeeded() -> Bool {
        guard state.isEdited else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to \(state.displayTitle)?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmSaveIfNeeded()
    }

    private func load(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            state.load(text: text, from: url)
        } catch {
            showError(title: "Open Failed", message: error.localizedDescription)
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private var markdownContentTypes: [UTType] {
        ["md", "markdown", "mdwn", "mdown"].compactMap {
            UTType(filenameExtension: $0)
        }
    }
}
```

- [ ] **Step 3: Run tests and build**

Run:

```bash
swift test
swift build
```

Expected: PASS.

- [ ] **Step 4: Commit the app shell and file coordinator**

```bash
git add Sources/MarkdoneViewer
git commit -m "feat: add macos document viewer shell"
```

---

### Task 8: App Bundle Metadata And Local Build Script

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/build-app.sh`

- [ ] **Step 1: Create app bundle metadata**

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MarkdoneViewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.henry.markdone-viewer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Markdone Viewer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown File</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdwn</string>
                <string>mdown</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Create the app bundle build script**

Create `Scripts/build-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
PRODUCT_NAME="MarkdoneViewer"
BUNDLE_NAME="Markdone Viewer.app"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$PRODUCT_NAME"
APP_DIR="$ROOT_DIR/build/$BUNDLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
```

- [ ] **Step 3: Make the script executable and verify syntax**

Run:

```bash
chmod +x Scripts/build-app.sh
bash -n Scripts/build-app.sh
```

Expected: PASS with no shell syntax output.

- [ ] **Step 4: Build the app bundle**

Run:

```bash
Scripts/build-app.sh
```

Expected: command prints `build/Markdone Viewer.app` and exits with status `0`.

- [ ] **Step 5: Commit bundle metadata**

```bash
git add Resources/Info.plist Scripts/build-app.sh
git commit -m "chore: add app bundle metadata"
```

---

### Task 9: End-To-End Verification

**Files:**
- No file changes expected.

- [ ] **Step 1: Run the automated verification suite**

Run:

```bash
swift test
swift build
Scripts/build-app.sh
```

Expected: all commands exit with status `0`.

- [ ] **Step 2: Run the release parser performance check**

Run:

```bash
MARKDONE_PERF_TEST=1 swift test -c release --filter MarkdownParserTests/performanceBudget
```

Expected: PASS with the 100KB parser check under 100ms.

- [ ] **Step 3: Launch the local app bundle**

Run:

```bash
open "build/Markdone Viewer.app"
```

Expected: the app opens a single window titled `Untitled` in Preview mode.

- [ ] **Step 4: Create a manual verification Markdown file**

Run:

````bash
cat > /tmp/markdone-viewer-manual.md <<'MARKDOWN'
# Markdone Viewer

Hello **bold** *italic* `code`.

- unordered
* second unordered

1. ordered
2. second ordered

> quote line
> 第二行

---

[OpenAI](https://openai.com)

```swift
let value = "中文 + English"

print(value)
```
MARKDOWN
````

Expected: `/tmp/markdone-viewer-manual.md` exists and contains all v1 syntax examples except images.

- [ ] **Step 5: Open the manual file from Finder-style launch**

Run:

```bash
open -a "$PWD/build/Markdone Viewer.app" /tmp/markdone-viewer-manual.md
```

Expected: the existing app window loads `/tmp/markdone-viewer-manual.md`, shows Preview mode, renders headings/lists/quote/rule/code/link, and the window title changes to `markdone-viewer-manual.md`.

- [ ] **Step 6: Verify editing and saving manually**

In the app:

1. Press `⌘E`.
2. Append `Saved from Markdone Viewer.` to the document.
3. Press `⌘S`.
4. Press `⌘E`.

Then run:

```bash
tail -n 1 /tmp/markdone-viewer-manual.md
```

Expected: output is `Saved from Markdone Viewer.`

- [ ] **Step 7: Verify unsaved-change prompts manually**

In the app:

1. Press `⌘E`.
2. Add a new line without saving.
3. Press `⌘O`.

Expected: an alert offers `Save`, `Discard`, and `Cancel`. `Cancel` keeps the current document open with edits preserved. `Discard` allows selecting another file. `Save` writes the current document before selecting another file.

- [ ] **Step 8: Commit verification notes only if files changed**

Run:

```bash
git status --short
```

Expected: no source changes. If executable mode changed on `Scripts/build-app.sh` in Task 8, commit that mode change with Task 8 before this verification task.

---

## Self-Review

- Spec coverage: file open/save/save-as, Finder open bridge, unsaved-change prompts, single-window replacement, edit/preview mode, parser support for v1 block and inline syntax, local images, font sizing controls, system colors, Markdown file association, and manual verification are covered by Tasks 2 through 9.
- Testing coverage: parser and state have automated tests; SwiftUI/AppKit behavior has build checks plus manual verification because native panels and window close prompts are UI workflows.
- Deliberate exclusions: v2 items from the spec remain unimplemented.
- Build-system decision: the first implementation uses SwiftPM and a deterministic app bundle script. Xcode 26 can open `Package.swift`; Developer ID archive, notarization, and DMG creation remain distribution operations after the v1 app is functionally verified.
