# markdone viewer — Design Spec

**Date**: 2026-06-08
**Status**: Refined Draft
**Author**: Henry

---

## 1. Overview

A lightweight, native macOS Markdown viewer with simple editing capability. Designed for reading and basic editing of one Markdown file at a time. No third-party dependencies, minimal footprint, Apple Silicon native with Intel compatibility.

### 1.1 Elevator Pitch

Think "Preview.app for Markdown" — open a `.md` file, read it rendered, flip to edit mode when you need to make changes, save and done.

---

## 2. Target Platform

| Requirement | Detail |
|-------------|--------|
| OS | macOS 14.0 (Sonoma) minimum — driven by `@Observable` macro availability. Covers all Apple Silicon Macs and Intel Macs that support Sonoma |
| Architecture | ARM64 native (Apple Silicon), x86_64 compatible (Intel) |
| Deployment | .app bundle, optionally DMG distribution |
| Apple Dev Account | Available for code signing |

---

## 3. Core Features (v1 — Basic Syntax)

### 3.1 File Handling

- **Open**: `⌘O` opens `NSOpenPanel` filtered to `.md` / `.markdown`
- **Save**: `⌘S` overwrites the original file
- **Save As**: `⌘⇧S` writes to a new path and makes that path the current file
- **File Association**: Register as handler for `net.daringfireball.markdown` UTI (`.md`, `.markdown`, `.mdwn`, `.mdown`)
- **Double-click**: Opens the file directly when `.md` is associated with the app
- **Unsaved Changes**: Opening another file, closing the window, or quitting prompts Save / Discard / Cancel when edits are unsaved
- **Scope**: v1 is single-window and single-document. Opening a new file replaces the current document after the unsaved-changes prompt.

### 3.2 Dual Mode: Edit / Preview

The app has exactly two modes, toggled via `⌘E` or a SegmentedControl in the toolbar:

| Mode | Component | Behavior |
|------|-----------|----------|
| **Edit** | SwiftUI `TextEditor` | Plain text editing, monospace font. No syntax highlighting (v1). |
| **Preview** | SwiftUI block renderer | Read-only rendered Markdown. Scrolling, selectable text for copy (`⌘C`) where supported. |

### 3.3 Markdown Syntax Support (v1)

| Syntax | Example | Preview Rendering |
|--------|---------|-------------------|
| Headings H1–H6 | `# Title` → `###### Title` | Cascading font sizes, bold weight |
| Bold | `**bold**` | Bold weight |
| Italic | `*italic*` | Italic |
| Inline code | `` `code` `` | Monospace + light gray background |
| Unordered list | `- item` or `* item` | Indent + bullet `•` |
| Ordered list | `1. item` | Indent + number |
| Blockquote | `> quote` | Left border + dimmed color |
| Horizontal rule | `---` or `***` | Centered line |
| Links | `[text](url)` | Blue, underlined, clickable → browser |
| Images | `![alt](path)` | Local images only, absolute path or relative to the Markdown file |
| Code blocks | ` ```lang ... ``` ` | Monospace block with background fill, no syntax highlighting |
| Paragraphs | Blank line separation | Natural paragraph spacing |

Deliberate v1 simplifications:

- Lists are flat only. Nested list rendering is a v2 item.
- Images do not load remote URLs. Remote image loading is a v2 item because it adds privacy, network, and sandbox questions.
- Unsupported Markdown syntax renders as plain text.

### 3.4 Font Strategy (Chinese + English)

- **UI font**: `.system(.body)` → macOS font cascade: SF Pro (Latin) → PingFang SC (CJK)
- **Monospace font**: SF Mono (Latin) + PingFang HK (CJK) for code
- **Line height**: Use `.system` defaults to ensure CJK and Latin characters align vertically
- **Dynamic Type**: Respect system font size settings, with manual `⌘+`/`⌘-` override in preview mode (`⌘0` to reset)

### 3.5 Theme

- Follow system appearance (Light / Dark) automatically via `@Environment(\.colorScheme)`
- No manual theme picker
- Background: systemBackground (white/black)
- Text: labelColor
- Links: systemBlue
- Code background: tertiarySystemFill

---

## 4. Future Items (v2+)

| Feature | Notes |
|---------|-------|
| Tables (`\| ... \|`) | Parser extension + column alignment |
| Task lists (`- [ ]`) | Checkbox rendering |
| Strikethrough (`~~text~~`) | Strikethrough attribute |
| Footnotes (`[^1]`) | Inline footnote rendering |
| Nested lists | Indentation-aware list rendering |
| Remote images | Optional network loading with clear user control |
| Syntax highlighting in edit mode | Light token-based coloring |
| Auto-save | debounced, non-blocking |
| Multiple windows | One document per window |

---

## 5. Architecture

### 5.1 Layer Diagram

```
┌──────────────────────────────────────┐
│          App Entry Layer              │
│  MarkdoneViewerApp.swift             │
│  • @main, WindowGroup                │
│  • Menu commands (Open, Save, etc.)  │
│  • NSApplicationDelegateAdaptor      │
│  AppDelegate.swift                   │
│  • application(_:open:) for Finder   │
│  AppCoordinator.swift                │
│  • file commands + save prompts      │
├──────────────────────────────────────┤
│          View Layer                   │
│  ContentView.swift                   │
│  • Mode toggle (Edit ↔ Preview)      │
│  • File path display in titlebar     │
│  EditModeView.swift                  │
│  • SwiftUI TextEditor bound to text  │
│  PreviewModeView.swift               │
│  • ScrollView + MarkdownBlock views  │
│  • Link tap → NSWorkspace.open(URL)  │
│  • Local image rendering             │
├──────────────────────────────────────┤
│          Parser Layer                 │
│  MarkdownParser.swift                │
│  • parse(_ source: String)           │
│      → [MarkdownBlock]               │
│  • Line scanner with fenced-code     │
│    state                             │
│  • Inline parser → AttributedString  │
└──────────────────────────────────────┘
```

v1 intentionally does not use `DocumentGroup`. A small AppDelegate bridge is enough for file association and keeps the first implementation focused.

### 5.2 Data Flow

```
.md file on disk
      │
      ▼
String (file contents)
      │
      ├── Edit mode: bound to TextEditor
      │      │
      │      ▼
      │   User edits text
      │      │
      │      ▼ (switch to Preview)
      │   MarkdownParser.parse(text, baseURL: fileURL)
      │      │
      │      ▼
      │   [MarkdownBlock] → SwiftUI preview blocks
      │
      ▼ (⌘S)
   Write back to file
```

### 5.3 State Management

Single `@Observable` class (iOS 17+ / macOS 14+ Observation framework):

```swift
@Observable
final class DocumentState {
    var fileURL: URL?
    var text: String = ""
    var lastSavedText: String = ""
    var mode: Mode = .preview  // default to preview on open
    var previewFontSize: CGFloat = 16

    var isEdited: Bool {
        text != lastSavedText
    }
}

enum Mode {
    case edit, preview
}
```

File loading sets both `text` and `lastSavedText`. Save updates `lastSavedText` only after the write succeeds.

---

## 6. Component Details

### 6.1 MarkdownParser

- **Input**: raw Markdown `String`
- **Output**: `[MarkdownBlock]`
- **Algorithm**: 
  1. Scan line by line
  2. Track fenced code blocks so blank lines inside code remain intact
  3. Identify simple block types: heading, paragraph, flat list, blockquote, horizontal rule, code block, local image
  4. Apply inline patterns (bold, italic, inline code, links) inside text blocks
  5. Return an ordered list of blocks for `PreviewModeView`
- **Performance target**: < 50ms for a 100KB file (well within budget for synchronous parsing on every mode switch)
- **Error handling**: Malformed syntax renders as-is (graceful degradation). No crashes on malformed input.

### 6.1.1 MarkdownBlock

Small enum used only between parser and preview renderer:

```swift
enum MarkdownBlock {
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

### 6.2 EditModeView

- `TextEditor` with `.font(.system(.body, design: .monospaced))` 
- No line numbers, no minimap
- Modified indicator: `•` in titlebar close button (standard macOS behavior via `isDocumentEdited`)

### 6.3 PreviewModeView

- `ScrollView` containing one SwiftUI view per `MarkdownBlock`
- Text blocks use `Text(AttributedString)` with `.textSelection(.enabled)`
- Link detection: custom `openURL` environment handler
- Images: local `NSImage(contentsOf:)` loaded from the Markdown file's directory or absolute path
- Font size: adjustable via `⌘+` / `⌘-`, persisted in `DocumentState`

### 6.4 ContentView

- Toolbar with `SegmentedControl` (Edit / Preview)
- Title displays file name, or "Untitled" if no file
- Receives open-file events from `AppDelegate` through a small app coordinator
- Updates window edited indicator from `DocumentState.isEdited`
- Before destructive navigation (open new file, close, quit), asks the coordinator to run the unsaved-changes prompt

---

## 7. Project Structure

```
markdone-viewer/
├── markdone-viewer.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── MarkdoneViewerApp.swift
│   │   ├── AppDelegate.swift
│   │   └── AppCoordinator.swift
│   ├── Model/
│   │   ├── DocumentState.swift
│   │   └── MarkdownBlock.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── EditModeView.swift
│   │   └── PreviewModeView.swift
│   ├── Parser/
│   │   ├── MarkdownParser.swift
│   │   └── InlineMarkdownParser.swift
├── Resources/
│   ├── Assets.xcassets/
│   │   └── AppIcon.iconset/
│   └── Info.plist
└── Tests/
    └── MarkdownParserTests.swift
```

---

## 8. Menu Bar & Shortcuts

| Menu Item | Shortcut | Action |
|-----------|----------|--------|
| Open… | `⌘O` | Open file dialog |
| Save | `⌘S` | Write to current file |
| Save As… | `⌘⇧S` | Write to new file |
| Toggle Edit/Preview | `⌘E` | Switch mode |
| Copy (Preview) | `⌘C` | Copy selected text |
| Zoom In | `⌘+` | Increase preview font size |
| Zoom Out | `⌘-` | Decrease preview font size |
| Actual Size | `⌘0` | Reset preview font size |

### Deliberately Excluded

- Find/Replace (use system text editing if needed)
- Export HTML/PDF
- Print
- Recent files menu
- Auto-save
- Version browsing
- Remote image loading
- Multiple windows

---

## 9. File Association (Info.plist)

```xml
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
```

`LSHandlerRank: Alternate` means the app appears in "Open With" menu but doesn't steal default association on install. Users can set it as default via Finder → Get Info.

---

## 10. Testing Strategy

### Unit Tests

| Test Area | What |
|-----------|------|
| `MarkdownParserTests` | Each syntax type: headings, bold, italic, code, lists, blockquotes, links, images, code blocks, horizontal rules |
| `InlineMarkdownParserTests` | Bold, italic, inline code, links, malformed inline syntax |
| Edge cases | Empty input, blank lines in code blocks, malformed syntax, very long lines, CJK + Latin mixed, emoji |
| Regression | Golden-file tests: known input → expected block sequence |

### Manual Testing

| Scenario | Check |
|----------|-------|
| Open `.md` via double-click | File loads, Preview mode shown |
| Open via `⌘O` | Dialog works, file loads |
| Edit → Preview → Edit | Text preserved across mode switches |
| `⌘S` save | File on disk updated |
| Unsaved changes prompt | Open, close, and quit do not lose edits silently |
| Dark mode toggle | Both Edit and Preview follow system |
| CJK + English | Proper rendering, no font fallback gaps |
| Link click | Opens in default browser |
| Local image | Renders relative and absolute file paths |
| 100KB file | Parser completes under 50ms |

---

## 11. Build & Distribution

- **Build**: Xcode Archive → Organizer → Distribute App
- **Signing**: Developer ID Application certificate (Apple Dev account)
- **Notarization**: Required for distribution outside App Store
- **Distribution format**: `.app` inside `.dmg` with drag-to-Applications shortcut
- **Minimum deployment**: macOS 14.0 (Sonoma)
- **Swift language mode**: Swift 6 (with safety checks enabled)
- **App Sandbox**: disabled for v1 Developer ID distribution, so local images beside an opened Markdown file can load without security-scoped bookmark handling. Revisit if App Store distribution becomes a goal.

---

## 12. Non-Goals

- Real-time collaborative editing
- iCloud sync
- Multiple tabs/windows per session
- Plugin system
- Export to any format (HTML, PDF, RTF, etc.)
- File browser / project sidebar
- Settings/preferences window
- Touch Bar support
- App Store distribution (initially)
