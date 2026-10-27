import UIKit

public final class AppTheme: Sendable {
    public let appearance: ThemeAppearance
    public let accent: ThemeAccent
    public let font: ThemeFont
    public let contentSize: UIContentSizeCategory
    public let colors: ThemeColors
    public let fonts: ThemeFonts

    let inputs: ThemeInputs

    init(inputs: ThemeInputs, colors: ThemeColors, fonts: ThemeFonts) {
        self.inputs = inputs
        appearance = inputs.appearance
        accent = inputs.accent
        font = inputs.font
        contentSize = inputs.contentSize
        self.colors = colors
        self.fonts = fonts
    }
}
