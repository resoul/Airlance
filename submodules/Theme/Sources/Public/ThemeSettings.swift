public struct ThemeSettings: Codable, Equatable, Sendable {
    public static let `default` = ThemeSettings(mode: .system, accent: .blue, font: .montserrat)

    public var mode: ThemeMode
    public var accent: ThemeAccent
    public var font: ThemeFont

    public init(mode: ThemeMode, accent: ThemeAccent, font: ThemeFont) {
        self.mode = mode
        self.accent = accent
        self.font = font
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? container.decodeIfPresent(ThemeMode.self, forKey: .mode)) ?? Self.default.mode
        accent = (try? container.decodeIfPresent(ThemeAccent.self, forKey: .accent)) ?? Self.default.accent
        font = (try? container.decodeIfPresent(ThemeFont.self, forKey: .font)) ?? Self.default.font
    }
}
