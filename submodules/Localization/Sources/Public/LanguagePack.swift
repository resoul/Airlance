import Foundation

public final class LanguagePack: Sendable {
    private static let table = "Localizable"
    private static let missingValue = "\u{0}"

    public let language: LanguageCode
    public let locale: Locale

    private let bundle: Bundle
    private let fallbackBundle: Bundle?

    init(language: LanguageCode, bundle: Bundle, fallbackBundle: Bundle?) {
        self.language = language
        self.bundle = bundle
        self.fallbackBundle = fallbackBundle
        locale = Locale(identifier: language.rawValue)
    }

    public func string(_ key: String) -> String {
        if let value = Self.localized(key, in: bundle) {
            return value
        }

        if let fallbackBundle, let value = Self.localized(key, in: fallbackBundle) {
            return value
        }

        return key
    }

    public func format(_ key: String, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    private static func localized(_ key: String, in bundle: Bundle) -> String? {
        let value = bundle.localizedString(forKey: key, value: missingValue, table: table)

        return value == missingValue ? nil : value
    }
}
