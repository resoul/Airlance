import DatabaseAPI

extension StorageKey where Value == LanguageSettings {
    static let languageSettings = StorageKey("localization.settings", default: .default)
}
