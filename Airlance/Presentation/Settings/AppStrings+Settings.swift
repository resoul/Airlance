import Localization
import Theme

extension AppStrings {
    func title(for mode: ThemeMode) -> String {
        switch mode {
        case .system:
            themeModeSystem

        case .light:
            themeModeLight

        case .dark:
            themeModeDark
        }
    }

    func title(for accent: ThemeAccent) -> String {
        pack.string("theme.accent." + accent.rawValue)
    }

    func title(for schedule: NightSchedule) -> String {
        pack.string("theme.night." + schedule.rawValue)
    }

    func title(for style: NightStyle) -> String {
        pack.string("theme.nightStyle." + style.rawValue)
    }

    func title(for font: ThemeFont) -> String {
        switch font {
        case .montserrat:
            themeFontMontserrat

        case .system:
            themeFontSystem
        }
    }

    func title(for fill: BubbleFill) -> String {
        switch fill {
        case .solid:
            chatAppearanceFillSolid

        case .gradient:
            chatAppearanceFillGradient
        }
    }

    func title(for wallpaper: ChatWallpaper) -> String {
        pack.string("chat.appearance.wallpaper." + wallpaper.rawValue)
    }

    func title(for selection: LanguageSelection) -> String {
        switch selection {
        case .system:
            languageSystem

        case .language(let language):
            language.nativeName
        }
    }
}
