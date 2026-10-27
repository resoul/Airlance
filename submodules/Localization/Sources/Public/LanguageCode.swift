import Foundation

public struct LanguageCode: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var nativeName: String {
        let locale = Locale(identifier: rawValue)
        let name = locale.localizedString(forLanguageCode: rawValue) ?? rawValue

        return name.capitalized(with: locale)
    }
}
