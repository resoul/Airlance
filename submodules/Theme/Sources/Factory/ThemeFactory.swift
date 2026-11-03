import UIKit

enum ThemeFactory {
    static func makeTheme(_ inputs: ThemeInputs) -> AppTheme {
        let colors = makeColors(inputs)

        return AppTheme(
            inputs: inputs,
            colors: colors,
            fonts: FontFactory.makeFonts(font: inputs.font, contentSize: inputs.contentSize),
            chat: makeChat(inputs, accent: colors.accent)
        )
    }

    private static func makeChat(_ inputs: ThemeInputs, accent: UIColor) -> ThemeChat {
        let chat = inputs.chat
        let radius = clamp(chat.bubbleRadius, to: ChatAppearance.radiusRange)
        let size = clamp(chat.textSize, to: ChatAppearance.textSizeRange)
        let font = FontFactory.makeMessageFont(font: inputs.font, size: CGFloat(size), contentSize: inputs.contentSize)
        let gradient = ChatPalette.gradient(for: inputs.accent, appearance: inputs.appearance)

        return ThemeChat(
            outgoingColors: chat.fill == .gradient ? gradient : [accent],
            bubbleRadius: CGFloat(radius),
            messageFont: font,
            wallpaper: ChatPalette.wallpaper(chat.wallpaper, color: chat.wallpaperColor, appearance: inputs.appearance)
        )
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func makeColors(_ inputs: ThemeInputs) -> ThemeColors {
        let appearance = inputs.appearance
        let accent = inputs.accent
        let base = BasePalette.palette(for: appearance, style: inputs.nightStyle)

        return ThemeColors(
            background: base.background,
            surface: base.surface,
            textPrimary: base.textPrimary,
            textSecondary: base.textSecondary,
            accent: AccentPalette.color(for: accent, appearance: appearance),
            onAccent: .white,
            separator: base.separator,
            destructive: base.destructive
        )
    }
}
