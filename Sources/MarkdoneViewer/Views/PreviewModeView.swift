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
