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
        switch accent {
        case .blue:
            themeAccentBlue

        case .violet:
            themeAccentViolet

        case .green:
            themeAccentGreen
        }
    }

    func title(for font: ThemeFont) -> String {
        switch font {
        case .montserrat:
            themeFontMontserrat

        case .system:
            themeFontSystem
        }
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
