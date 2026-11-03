import UIKit

enum ChatPalette {
    static func gradient(for accent: ThemeAccent, appearance: ThemeAppearance) -> [UIColor] {
        switch (accent, appearance) {
        case (.blue, .light):
            [UIColor(rgb: 0x2F9BFF), UIColor(rgb: 0x5B5CF6)]

        case (.blue, .dark):
            [UIColor(rgb: 0x1E7BEA), UIColor(rgb: 0x4B3FD6)]

        case (.violet, .light):
            [UIColor(rgb: 0xD25BF0), UIColor(rgb: 0x7B4DF2)]

        case (.violet, .dark):
            [UIColor(rgb: 0xB04BD8), UIColor(rgb: 0x5E39C9)]

        case (.green, .light):
            [UIColor(rgb: 0x3DD47A), UIColor(rgb: 0x17A99B)]

        case (.green, .dark):
            [UIColor(rgb: 0x2BB565), UIColor(rgb: 0x0F8679)]
        }
    }

    static func wallpaper(_ kind: ChatWallpaper, appearance: ThemeAppearance) -> ThemeWallpaper? {
        let isDark = appearance == .dark
        let pattern = isDark ? UIColor.white.withAlphaComponent(0.07) : UIColor.black.withAlphaComponent(0.07)
        let colors: [UInt32]
        switch kind {
        case .none:
            return nil

        case .aurora:
            colors = isDark ? [0x0E2A3A, 0x2A1E4A, 0x3A1530] : [0xB7E4F9, 0xC9B8F5, 0xF5C7E0]

        case .sunset:
            colors = isDark ? [0x3A2410, 0x3A1A1A, 0x381A2E] : [0xFFE0B2, 0xFFB8A6, 0xF8A5C2]

        case .mint:
            colors = isDark ? [0x0F2E25, 0x163A2E, 0x24301A] : [0xD4F5E9, 0xB8E8D4, 0xE6F7C8]

        case .night:
            colors = isDark ? [0x0B1020, 0x16203A, 0x1F1830] : [0xC9D6EA, 0xA9B8D8, 0xD9D2EA]
        }

        return ThemeWallpaper(kind: kind, colors: colors.map(UIColor.init(rgb:)), pattern: pattern)
    }
}
