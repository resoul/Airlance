import Foundation
import Localization

extension LanguageCode {
    static let english = LanguageCode("en")
    static let ukrainian = LanguageCode("uk")
    static let spanish = LanguageCode("es")
}

extension LocalizationConfiguration {
    static let app = LocalizationConfiguration(
        bundle: .main,
        languages: [.english, .ukrainian, .spanish],
        baseLanguage: .english
    )
}
