import Foundation

enum LanguageResolver {
    static func language(
        for settings: LanguageSettings,
        configuration: LocalizationConfiguration,
        preferredLanguages: [String]
    ) -> LanguageCode {
        if case .language(let language) = settings.selection, configuration.languages.contains(language) {
            return language
        }

        let available = configuration.languages.map(\.rawValue)
        let preferred = Bundle.preferredLocalizations(from: available, forPreferences: preferredLanguages)

        return preferred.first.map(LanguageCode.init(rawValue:)) ?? configuration.baseLanguage
    }
}
