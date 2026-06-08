import Foundation

public struct InlineMarkdownRun: Equatable {
    public enum Trait: Hashable {
        case strong
        case emphasis
        case code
    }

    public let text: String
    public let traits: Set<Trait>
    public let link: URL?

    public static func runs(in value: AttributedString) -> [InlineMarkdownRun] {
        value.runs.map { run in
            var traits: Set<Trait> = []
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                traits.insert(.strong)
            }
            if run.inlinePresentationIntent?.contains(.emphasized) == true {
                traits.insert(.emphasis)
            }
            if run.inlinePresentationIntent?.contains(.code) == true {
                traits.insert(.code)
            }

            return InlineMarkdownRun(
                text: String(value[run.range].characters),
                traits: traits,
                link: run.link
            )
        }
    }
}
