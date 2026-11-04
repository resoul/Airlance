import Foundation
import Localization

extension LanguageCode {
    static let english = LanguageCode("en")
    static let ukrainian = LanguageCode("uk")
    static let spanish = LanguageCode("es")
    static let russian = LanguageCode("ru")
    static let italian = LanguageCode("it")
    static let romanian = LanguageCode("ro")
    static let french = LanguageCode("fr")
    static let german = LanguageCode("de")
}

extension LocalizationConfiguration {
    static let app = LocalizationConfiguration(
        bundle: .main,
        languages: [.english, .ukrainian, .spanish, .russian, .italian, .romanian, .french, .german],
        baseLanguage: .english
    )
}
