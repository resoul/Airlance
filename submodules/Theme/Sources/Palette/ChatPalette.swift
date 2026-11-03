import UIKit

enum ChatPalette {
    static func gradient(for accent: ThemeAccent, appearance: ThemeAppearance) -> [UIColor] {
        let colors = appearance == .dark ? darkGradient(accent) : lightGradient(accent)

        return colors.map(UIColor.init(rgb:))
    }

    private static func lightGradient(_ accent: ThemeAccent) -> [UInt32] {
        switch accent {
        case .blue:
            [0x2F9BFF, 0x5B5CF6]
        case .violet:
            [0xD25BF0, 0x7B4DF2]
        case .green:
            [0x3DD47A, 0x17A99B]
        case .teal:
            [0x3CC8D8, 0x2C7FD8]
        case .indigo:
            [0x7A6CF5, 0x3F8CF2]
        case .orange:
            [0xFFB347, 0xF2711C]
        case .pink:
            [0xFF7EB3, 0xB45CF0]
        case .red:
            [0xFF7A59, 0xE0335B]
        }
    }

    private static func darkGradient(_ accent: ThemeAccent) -> [UInt32] {
        switch accent {
        case .blue:
            [0x1E7BEA, 0x4B3FD6]
        case .violet:
            [0xB04BD8, 0x5E39C9]
        case .green:
            [0x2BB565, 0x0F8679]
        case .teal:
            [0x22A7B8, 0x2466B8]
        case .indigo:
            [0x6152E0, 0x2F6FD6]
        case .orange:
            [0xE89A2E, 0xC85A12]
        case .pink:
            [0xE05A95, 0x8A3FCF]
        case .red:
            [0xE0603F, 0xB8264A]
        }
    }

    static func wallpaper(_ kind: ChatWallpaper, color: UInt32, appearance: ThemeAppearance) -> ThemeWallpaper? {
        let isDark = appearance == .dark
        let pattern = isDark ? UIColor.white.withAlphaComponent(0.07) : UIColor.black.withAlphaComponent(0.07)
        let colors: [UInt32]
        switch kind {
        case .none:
            return nil
        case .color:
            let base = UIColor(rgb: color)

            return ThemeWallpaper(kind: kind, colors: [base, base], pattern: .clear)
        case .photo:
            return ThemeWallpaper(kind: kind, colors: [.black, .black], pattern: .clear)
        default:
            colors = gradient(of: kind, isDark: isDark)
        }

        return ThemeWallpaper(kind: kind, colors: colors.map(UIColor.init(rgb:)), pattern: pattern)
    }

    private static func gradient(of kind: ChatWallpaper, isDark: Bool) -> [UInt32] {
        switch kind {
        case .aurora:
            isDark ? [0x0E2A3A, 0x2A1E4A, 0x3A1530] : [0xB7E4F9, 0xC9B8F5, 0xF5C7E0]
        case .sunset:
            isDark ? [0x3A2410, 0x3A1A1A, 0x381A2E] : [0xFFE0B2, 0xFFB8A6, 0xF8A5C2]
        case .mint:
            isDark ? [0x0F2E25, 0x163A2E, 0x24301A] : [0xD4F5E9, 0xB8E8D4, 0xE6F7C8]
        case .night:
            isDark ? [0x0B1020, 0x16203A, 0x1F1830] : [0xC9D6EA, 0xA9B8D8, 0xD9D2EA]
        case .frost:
            isDark ? [0x0C1E2E, 0x12324A, 0x0E2238] : [0xDDF1FF, 0xC2E2F8, 0xE8F0FF]
        case .love:
            isDark ? [0x2A0E24, 0x3A1236, 0x24102E] : [0xFFD6E8, 0xF5C2EC, 0xE6CCFF]
        case .holiday:
            isDark ? [0x0E2A1A, 0x2E1010, 0x13261A] : [0xD8F0DC, 0xFFD9D2, 0xFFF0C8]
        case .games:
            isDark ? [0x140E2E, 0x0E2234, 0x2A0E2E] : [0xD9D2FF, 0xC8ECFF, 0xFFD2F0]
        case .school:
            isDark ? [0x10222A, 0x182A20, 0x1E2030] : [0xE4F2EA, 0xDDEBF5, 0xEDE8F7]
        case .space:
            isDark ? [0x05060F, 0x0D1030, 0x1A0B2A] : [0x2A2F5A, 0x3A2A62, 0x1C2A4A]
        case .none, .color, .photo:
            [0x000000, 0x000000]
        }
    }
}
