import UIKit

enum AccentPalette {
    static func color(for accent: ThemeAccent, appearance: ThemeAppearance) -> UIColor {
        let (light, dark) = values(accent)

        return UIColor(rgb: appearance == .dark ? dark : light)
    }

    private static func values(_ accent: ThemeAccent) -> (UInt32, UInt32) {
        switch accent {
        case .blue:
            (0x007AFF, 0x0A84FF)
        case .violet:
            (0xAF52DE, 0xBF5AF2)
        case .green:
            (0x34C759, 0x30D158)
        case .teal:
            (0x0FA3B1, 0x40C8E0)
        case .indigo:
            (0x5856D6, 0x6E6CF0)
        case .orange:
            (0xF2860E, 0xFF9F0A)
        case .pink:
            (0xE0457B, 0xFF5C93)
        case .red:
            (0xE5383B, 0xFF5A52)
        }
    }
}
