import UIKit

struct ThemeInputs: Equatable, Sendable {
    let appearance: ThemeAppearance
    let accent: ThemeAccent
    let font: ThemeFont
    let contentSize: UIContentSizeCategory
    let chat: ChatAppearance

    init(settings: ThemeSettings, system: SystemTraits) {
        appearance = Self.appearance(for: settings.mode, system: system.appearance)
        accent = settings.accent
        font = settings.font
        contentSize = system.contentSize
        chat = settings.chat
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
