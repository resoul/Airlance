public enum LanguageSelection: Codable, Equatable, Sendable {
    case system
    case language(LanguageCode)
}

public struct LanguageSettings: Codable, Equatable, Sendable {
    public static let `default` = LanguageSettings(selection: .system)

    public var selection: LanguageSelection

    public init(selection: LanguageSelection) {
        self.selection = selection
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selection = (try? container.decodeIfPresent(LanguageSelection.self, forKey: .selection))
            ?? Self.default.selection
    }
}
