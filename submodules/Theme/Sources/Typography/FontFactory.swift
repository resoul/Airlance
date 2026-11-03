import UIKit

enum FontFactory {
    static func makeFonts(font: ThemeFont, contentSize: UIContentSizeCategory) -> ThemeFonts {
        let traits = UITraitCollection(preferredContentSizeCategory: contentSize)

        return ThemeFonts(
            largeTitle: makeFont(.largeTitle, font: font, traits: traits),
            title: makeFont(.title, font: font, traits: traits),
            headline: makeFont(.headline, font: font, traits: traits),
            body: makeFont(.body, font: font, traits: traits),
            subheadline: makeFont(.subheadline, font: font, traits: traits),
            caption: makeFont(.caption, font: font, traits: traits)
        )
    }

    static func makeMessageFont(font: ThemeFont, size: CGFloat, contentSize: UIContentSizeCategory) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: contentSize)
        let base = font == .montserrat
            ? UIFont(name: montserratName(for: .regular), size: size) ?? .systemFont(ofSize: size)
            : .systemFont(ofSize: size)

        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: traits)
    }

    private static func makeFont(_ style: TypeStyle, font: ThemeFont, traits: UITraitCollection) -> UIFont {
        let base = baseFont(style, font: font)

        return UIFontMetrics(forTextStyle: style.textStyle).scaledFont(for: base, compatibleWith: traits)
    }

    private static func baseFont(_ style: TypeStyle, font: ThemeFont) -> UIFont {
        switch font {
        case .montserrat:
            UIFont(name: montserratName(for: style.weight), size: style.size)
                ?? .systemFont(ofSize: style.size, weight: style.weight)

        case .system:
            .systemFont(ofSize: style.size, weight: style.weight)
        }
    }

    private static func montserratName(for weight: UIFont.Weight) -> String {
        switch weight {
        case .bold:
            "Montserrat-Bold"

        case .semibold:
            "Montserrat-SemiBold"

        case .medium:
            "Montserrat-Medium"

        default:
            "Montserrat-Regular"
        }
    }
}
