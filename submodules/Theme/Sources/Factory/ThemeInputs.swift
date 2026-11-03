import UIKit

struct ThemeInputs: Equatable, Sendable {
    let appearance: ThemeAppearance
    let nightStyle: NightStyle
    let accent: ThemeAccent
    let font: ThemeFont
    let contentSize: UIContentSizeCategory
    let chat: ChatAppearance

    init(settings: ThemeSettings, system: SystemTraits, clock: ThemeClock) {
        appearance = Self.appearance(for: settings, system: system.appearance, clock: clock)
        nightStyle = settings.night.style
        accent = settings.accent
        font = settings.font
        contentSize = system.contentSize
        chat = settings.chat
    }

    private static func appearance(
        for settings: ThemeSettings,
        system: ThemeAppearance,
        clock: ThemeClock
    ) -> ThemeAppearance {
        switch settings.night.schedule {
        case .system:
            system
        case .off:
            settings.mode == .dark ? .dark : .light
        case .scheduled, .automatic:
            settings.night.isNight(clock: clock) ? .dark : .light
        }
    }
}
