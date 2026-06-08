import Foundation

public enum MarkdownParser {
    public static func parse(_ source: String, markdownFileURL: URL? = nil) -> [MarkdownBlock] {
        let normalizedSource = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedSource.components(separatedBy: .newlines)
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

            if isRemoteImage(trimmed) {
                blocks.append(.paragraph(AttributedString(trimmed)))
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
            || isRemoteImage(trimmed)
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
        guard let image = imageComponents(in: line) else {
            return nil
        }

        guard !image.path.contains("://") else {
            return nil
        }

        let url: URL
        if image.path.hasPrefix("/") {
            url = URL(fileURLWithPath: image.path)
        } else if let markdownFileURL {
            url = markdownFileURL
                .deletingLastPathComponent()
                .appendingPathComponent(image.path)
        } else {
            url = URL(fileURLWithPath: image.path)
        }

        return .image(alt: image.alt, url: url)
    }

    private static func isRemoteImage(_ line: String) -> Bool {
        guard let image = imageComponents(in: line) else {
            return false
        }

        return image.path.contains("://")
    }

    private static func imageComponents(in line: String) -> (alt: String, path: String)? {
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
        return (alt, path)
    }
}
