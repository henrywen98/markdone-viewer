# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Markdone Viewer is a Swift Package Manager macOS app for viewing and lightly editing one local Markdown document at a time. It targets macOS 14+ with SwiftUI/AppKit for the app layer and a separate `MarkdoneViewerCore` library for document state and Markdown parsing.

## Common Commands

```bash
# Run all tests
swift test

# Run one test suite
swift test --filter MarkdownParserTests
swift test --filter InlineMarkdownParserTests
swift test --filter DocumentStateTests

# Run the release-only parser performance gate
MARKDONE_PERF_TEST=1 swift test -c release --filter MarkdownParserTests/performanceBudget

# Build the debug executable
swift build

# Build the local .app bundle (default: release)
Scripts/build-app.sh

# Build a debug .app bundle
Scripts/build-app.sh debug

# Launch the bundled app
open "build/Markdone Viewer.app"

# Launch the app with a Markdown file
open -a "$PWD/build/Markdone Viewer.app" /path/to/file.md
```

SwiftPM/Clang may write module caches under the user home directory. If sandboxed Swift commands fail with cache-permission errors, rerun the same command with elevated sandbox permissions rather than changing project code.

## Architecture

The package has three targets:

- `MarkdoneViewerCore`: pure Foundation/Observation library with document state and Markdown parsing. Keep this target free of SwiftUI/AppKit.
- `MarkdoneViewer`: SwiftUI/AppKit executable target that owns windows, menus, file panels, prompts, and rendering.
- `MarkdoneViewerCoreTests`: Swift Testing tests for state and parser behavior.

Core data flow:

1. `DocumentState` holds the single open document: `fileURL`, `text`, `lastSavedText`, mode (`edit`/`preview`), and preview font size. `isEdited` is derived from `text != lastSavedText`; use `load(text:from:)` and `markSaved(fileURL:)` to keep that invariant intact.
2. `MarkdownParser` converts document text into `[MarkdownBlock]`. It delegates inline styling to `InlineMarkdownParser` for bold, italic, inline code, and links.
3. `ContentView` switches between `EditModeView` and `PreviewModeView` based on `DocumentState.mode` and provides the mode picker toolbar.
4. `PreviewModeView` renders parsed blocks in native SwiftUI. It caches parsed blocks in `@State` keyed by `text` and `fileURL`, so visual-only changes such as font-size updates should not trigger reparsing.
5. `MarkdoneViewerApp` creates the app-lifetime `DocumentState` and `AppCoordinator`, wires menu commands, and installs `AppDelegate` handlers once the content view appears.
6. `AppDelegate` buffers Finder/double-click open URLs until the coordinator handler is installed. This is a single-document app; keep only one pending URL and only open the first URL from each OS open event.
7. `AppCoordinator` is the AppKit bridge for open/save/save-as, save confirmation, window close handling, and error alerts. File reads/writes go through the `FileService` protocol (`LocalFileService` in production) so I/O can be isolated from coordinator logic.
8. `WindowConfigurator` attaches AppKit window state (title, edited indicator, close delegate) from SwiftUI.

## Build and Bundle Notes

`Scripts/build-app.sh` builds the `MarkdoneViewer` SwiftPM product, assembles `build/Markdone Viewer.app`, copies `Resources/Info.plist`, writes `PkgInfo`, and ad-hoc signs with `codesign --force --sign -`.

`Resources/Info.plist` registers Markdown file types (`md`, `markdown`, `mdwn`, `mdown`) with `LSHandlerRank` set to `Alternate`.

## Testing Notes

Parser and document-state behavior are covered by automated tests. SwiftUI/AppKit workflows (file panels, Finder open, close/save prompts) are primarily verified by building the app bundle and manually launching it.

The parser performance test has two modes:

- Default `swift test`: loose debug budget (`< 1s`) so normal debug runs are stable.
- `MARKDONE_PERF_TEST=1 swift test -c release --filter MarkdownParserTests/performanceBudget`: release budget (`< 100ms`) for the 100KB parser check.

## Current Product Constraints

- Single-document app: opening another file replaces the current document after save confirmation.
- Markdown support is intentionally small: headings, paragraphs, unordered/ordered lists, blockquotes, horizontal rules, fenced code, local images, and basic inline emphasis/code/links.
- Remote image syntax stays literal text; local images resolve relative to the Markdown file URL.
- File I/O is UTF-8 only.
