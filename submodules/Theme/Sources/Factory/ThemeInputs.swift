import UIKit

struct ThemeInputs: Equatable, Sendable {
    let appearance: ThemeAppearance
    let accent: ThemeAccent
    let font: ThemeFont
    let contentSize: UIContentSizeCategory

    init(settings: ThemeSettings, system: SystemTraits) {
        appearance = Self.appearance(for: settings.mode, system: system.appearance)
        accent = settings.accent
        font = settings.font
        contentSize = system.contentSize
    }

    private static func appearance(for mode: ThemeMode, system: ThemeAppearance) -> ThemeAppearance {
        switch mode {
        case .system:
            system

        case .light:
            .light

        case .dark:
            .dark
        }
    }
}
