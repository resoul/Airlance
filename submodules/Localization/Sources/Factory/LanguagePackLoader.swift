import Foundation

enum LanguagePackLoader {
    static func load(_ language: LanguageCode, configuration: LocalizationConfiguration) -> LanguagePack {
        let baseBundle = bundle(for: configuration.baseLanguage, in: configuration.bundle)
        let languageBundle = bundle(for: language, in: configuration.bundle)
        let isBase = language == configuration.baseLanguage

        return LanguagePack(
            language: language,
            bundle: languageBundle ?? baseBundle ?? configuration.bundle,
            fallbackBundle: isBase ? nil : baseBundle
        )
    }

    private static func bundle(for language: LanguageCode, in bundle: Bundle) -> Bundle? {
        bundle
            .path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:))
    }
}
