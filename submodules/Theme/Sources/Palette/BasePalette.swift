import UIKit

struct BasePalette {
    static let light = BasePalette(
        background: UIColor(rgb: 0xFFFFFF),
        surface: UIColor(rgb: 0xF2F2F7),
        textPrimary: UIColor(rgb: 0x000000),
        textSecondary: UIColor(rgb: 0x8E8E93),
        separator: UIColor(rgb: 0xC6C6C8),
        destructive: UIColor(rgb: 0xFF3B30)
    )

    static let dark = BasePalette(
        background: UIColor(rgb: 0x000000),
        surface: UIColor(rgb: 0x1C1C1E),
        textPrimary: UIColor(rgb: 0xFFFFFF),
        textSecondary: UIColor(rgb: 0x8E8E93),
        separator: UIColor(rgb: 0x38383A),
        destructive: UIColor(rgb: 0xFF453A)
    )

    static let tinted = BasePalette(
        background: UIColor(rgb: 0x18222D),
        surface: UIColor(rgb: 0x212F3D),
        textPrimary: UIColor(rgb: 0xFFFFFF),
        textSecondary: UIColor(rgb: 0x7F8D9C),
        separator: UIColor(rgb: 0x2F3E4E),
        destructive: UIColor(rgb: 0xFF5E57)
    )

    let background: UIColor
    let surface: UIColor
    let textPrimary: UIColor
    let textSecondary: UIColor
    let separator: UIColor
    let destructive: UIColor

    static func palette(for appearance: ThemeAppearance, style: NightStyle) -> BasePalette {
        switch (appearance, style) {
        case (.light, _):
            light
        case (.dark, .night):
            dark
        case (.dark, .tinted):
            tinted
        }
    }
}
