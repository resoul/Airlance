import ListUI
import UIKit

extension OnAirLevel {
    var color: UIColor {
        switch self {
        case .none:
            .systemGray
        case .bronze:
            OnAirLevel.medals[2]
        case .silver:
            OnAirLevel.medals[1]
        case .gold:
            OnAirLevel.medals[0]
        case .diamond:
            UIColor(red: 0.45, green: 0.85, blue: 1, alpha: 1)
        }
    }

    var symbol: String {
        self == .diamond ? "diamond.fill" : "star.circle.fill"
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .none:
            strings.onAirLevelNone
        case .bronze:
            strings.onAirLevelBronze
        case .silver:
            strings.onAirLevelSilver
        case .gold:
            strings.onAirLevelGold
        case .diamond:
            strings.onAirLevelDiamond
        }
    }

    func badge(font: UIFont) -> NSAttributedString {
        guard self != .none else {
            return NSAttributedString()
        }

        let image = ListRowSymbols.image(symbol, size: font.pointSize * 0.9, color: color, weight: .semibold)
        let text = NSMutableAttributedString(string: " ")
        text.append(NSAttributedString(attachment: OnAirName.attachment(image, font: font)))

        return text
    }
}

enum OnAirName {
    static func text(
        _ name: String,
        level: OnAirLevel,
        isJoined: Bool,
        font: UIFont,
        color: UIColor,
        accent: UIColor
    ) -> NSAttributedString {
        let text = NSMutableAttributedString(string: name, attributes: [.font: font, .foregroundColor: color])
        text.append(level.badge(font: font))
        if isJoined {
            let image = ListRowSymbols.image("checkmark.circle.fill", size: font.pointSize * 0.9, color: accent)
            text.append(NSAttributedString(string: " "))
            text.append(NSAttributedString(attachment: attachment(image, font: font)))
        }

        return text
    }

    static func attachment(_ image: UIImage, font: UIFont) -> NSTextAttachment {
        let attachment = NSTextAttachment(image: image)
        let size = image.size
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)

        return attachment
    }
}
