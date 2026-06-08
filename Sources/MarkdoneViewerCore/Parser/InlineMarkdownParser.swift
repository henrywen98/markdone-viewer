import Foundation

public enum InlineMarkdownParser {
    public static func parse(_ source: String) -> AttributedString {
        var output = AttributedString()
        var index = source.startIndex

        while index < source.endIndex {
            if source[index...].hasPrefix("**") {
                guard let match = parseDelimited(
                    source,
                    openingAt: index,
                    delimiter: "**",
                    intent: .stronglyEmphasized
                ) else {
                    append("**", to: &output)
                    index = source.index(index, offsetBy: 2)
                    continue
                }

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
               !source[index...].hasPrefix("**") {
                guard let match = parseDelimited(
                    source,
                    openingAt: index,
                    delimiter: "*",
                    intent: .emphasized
                ) else {
                    append("*", to: &output)
                    index = source.index(after: index)
                    continue
                }

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
            return (
                AttributedString(String(source[index...])),
                source.endIndex
            )
        }

        let text = String(source[textStart..<closeBracket])
        let urlText = String(source[urlStart..<closeParen])
        guard !text.isEmpty,
              let url = URL(string: urlText),
              url.scheme != nil else {
            return (
                AttributedString(String(source[index...closeParen])),
                source.index(after: closeParen)
            )
        }

        var value = AttributedString(text)
        value.link = url
        return (value, source.index(after: closeParen))
    }

    private static func append(_ text: String, to output: inout AttributedString) {
        output += AttributedString(text)
    }
}
