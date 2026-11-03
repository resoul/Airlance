import UIKit

enum SubtitleText {
    static func fontSize(width: CGFloat) -> CGFloat {
        width * 0.068
    }

    static func attributed(
        _ phrase: SubtitlePhrase,
        highlight: Int?,
        style: SubtitleStyle,
        width: CGFloat
    ) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize(width: width), weight: .heavy)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(style == .shadow ? 0.75 : 0)
        shadow.shadowOffset = CGSize(width: 0, height: width * 0.004)
        shadow.shadowBlurRadius = width * 0.01
        let text = NSMutableAttributedString()
        for (index, word) in phrase.words.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: " "))
            }
            text.append(NSAttributedString(string: word.text, attributes: [
                .foregroundColor: color(style, isHighlighted: index == highlight),
            ]))
        }
        text.addAttributes(
            [.font: font, .paragraphStyle: paragraph, .shadow: shadow],
            range: NSRange(location: 0, length: text.length)
        )

        return text
    }

    static func plateColor(_ style: SubtitleStyle) -> UIColor? {
        switch style {
        case .shadow:
            nil
        case .plate:
            UIColor.black.withAlphaComponent(0.6)
        case .pop:
            .white
        }
    }

    static func frame(for text: NSAttributedString, position: CGFloat, in size: CGSize) -> CGRect {
        let inset = size.width * 0.08
        let padding = size.width * 0.025
        let fitted = text.boundingRect(
            with: CGSize(width: size.width - inset * 2 - padding * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.size
        let plate = CGSize(width: fitted.width + padding * 2, height: fitted.height + padding)
        let centerY = min(max(size.height * position, plate.height / 2), size.height - plate.height / 2)

        return CGRect(
            x: (size.width - plate.width) / 2,
            y: centerY - plate.height / 2,
            width: plate.width,
            height: plate.height
        )
    }

    private static func color(_ style: SubtitleStyle, isHighlighted: Bool) -> UIColor {
        switch style {
        case .shadow, .plate:
            isHighlighted ? .systemYellow : .white
        case .pop:
            isHighlighted ? .systemRed : .black
        }
    }
}
