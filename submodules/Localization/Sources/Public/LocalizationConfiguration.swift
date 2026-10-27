import Foundation

public struct LocalizationConfiguration: Sendable {
    public let bundle: Bundle
    public let languages: [LanguageCode]
    public let baseLanguage: LanguageCode

    public init(bundle: Bundle, languages: [LanguageCode], baseLanguage: LanguageCode) {
        self.bundle = bundle
        self.languages = languages
        self.baseLanguage = baseLanguage
    }
}
