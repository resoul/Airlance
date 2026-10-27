import DatabaseAPI

extension StorageKey where Value == ThemeSettings {
    static let themeSettings = StorageKey("theme.settings", default: .default)
}
