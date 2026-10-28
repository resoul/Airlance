enum ThemeFactory {
    static func makeTheme(_ inputs: ThemeInputs) -> AppTheme {
        AppTheme(
            inputs: inputs,
            colors: makeColors(appearance: inputs.appearance, accent: inputs.accent),
            fonts: FontFactory.makeFonts(font: inputs.font, contentSize: inputs.contentSize)
        )
    }

    private static func makeColors(appearance: ThemeAppearance, accent: ThemeAccent) -> ThemeColors {
        let base = BasePalette.palette(for: appearance)

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
