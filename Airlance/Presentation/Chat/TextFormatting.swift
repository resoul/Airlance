import ChatHistory
import UIKit

enum TextFormatting {
    static let quoteIndent: CGFloat = 11
    static let preIndent: CGFloat = 9
    static let blockSpacing: CGFloat = 5

    static func apply(
        _ entities: [MessageEntity],
        to text: NSMutableAttributedString,
        font: UIFont,
        codeFill: UIColor
    ) {
        for entity in entities where entity.isCode {
            text.addAttribute(.font, value: mono(font), range: entity.range)
            if entity.kind == .code {
                text.addAttribute(.backgroundColor, value: codeFill, range: entity.range)
            }
        }
        for entity in entities {
            switch entity.kind {
            case .bold:
                embolden(text, range: entity.range)
            case .italic:
                text.addAttribute(.obliqueness, value: 0.18, range: entity.range)
            case .strikethrough:
                text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: entity.range)
            case .pre, .quote:
                indent(text, range: entity.range, by: entity.kind == .quote ? quoteIndent : preIndent)
            case .spoiler, .mention, .code:
                break
            }
        }
    }

    static func mono(_ font: UIFont, bold: Bool = false) -> UIFont {
        .monospacedSystemFont(ofSize: round(font.pointSize * 0.92), weight: bold ? .semibold : .regular)
    }

    private static func embolden(_ text: NSMutableAttributedString, range: NSRange) {
        text.enumerateAttribute(.font, in: range) { value, run, _ in
            guard let font = value as? UIFont else {
                return
            }

            let isMono = font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
            text.addAttribute(.font, value: isMono ? mono(font, bold: true) : HistoryStyle.bold(font), range: run)
        }
    }

    private static func indent(_ text: NSMutableAttributedString, range: NSRange, by indent: CGFloat) {
        let string = text.string as NSString
        let paragraphs = string.paragraphRange(for: range)
        let last = string.paragraphRange(for: NSRange(location: NSMaxRange(range) - 1, length: 0))
        string.enumerateSubstrings(in: paragraphs, options: .byParagraphs) { _, _, enclosing, _ in
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = indent
            style.headIndent = indent
            style.tailIndent = -indent
            if enclosing.location == paragraphs.location {
                style.paragraphSpacingBefore = blockSpacing
            }
            if enclosing.location == last.location {
                style.paragraphSpacing = blockSpacing
            }
            text.addAttribute(.paragraphStyle, value: style, range: enclosing)
        }
    }
}
