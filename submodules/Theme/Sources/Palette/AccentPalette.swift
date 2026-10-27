import UIKit

enum AccentPalette {
    static func color(for accent: ThemeAccent, appearance: ThemeAppearance) -> UIColor {
        switch (accent, appearance) {
        case (.blue, .light):
            UIColor(rgb: 0x007AFF)

        case (.blue, .dark):
            UIColor(rgb: 0x0A84FF)

        case (.violet, .light):
            UIColor(rgb: 0xAF52DE)

        case (.violet, .dark):
            UIColor(rgb: 0xBF5AF2)

        case (.green, .light):
            UIColor(rgb: 0x34C759)

        case (.green, .dark):
            UIColor(rgb: 0x30D158)
        }
    }
}
