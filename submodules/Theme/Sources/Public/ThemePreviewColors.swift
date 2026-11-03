import UIKit

extension ThemeAccent {
    public func color(for appearance: ThemeAppearance) -> UIColor {
        AccentPalette.color(for: self, appearance: appearance)
    }

    public func bubbleColors(for appearance: ThemeAppearance) -> [UIColor] {
        ChatPalette.gradient(for: self, appearance: appearance)
    }
}

extension NightStyle {
    public var background: UIColor {
        BasePalette.palette(for: .dark, style: self).background
    }

    public var surface: UIColor {
        BasePalette.palette(for: .dark, style: self).surface
    }
}
