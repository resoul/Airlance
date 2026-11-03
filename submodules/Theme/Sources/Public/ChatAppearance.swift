public enum BubbleFill: String, Codable, Sendable, CaseIterable {
    case solid
    case gradient
}

public enum ChatWallpaper: String, Codable, Sendable, CaseIterable {
    case none
    case aurora
    case sunset
    case mint
    case night
    case frost
    case love
    case holiday
    case games
    case school
    case space
    case color
    case photo
}

public struct ChatAppearance: Codable, Equatable, Sendable {
    public static let `default` = ChatAppearance(fill: .solid, bubbleRadius: 17, textSize: 17, wallpaper: .none)
    public static let defaultColor: UInt32 = 0x3A6EA5
    public static let radiusRange = 4...22
    public static let textSizeRange = 13...24

    public var fill: BubbleFill
    public var bubbleRadius: Int
    public var textSize: Int
    public var wallpaper: ChatWallpaper
    public var wallpaperColor = Self.defaultColor

    public init(fill: BubbleFill, bubbleRadius: Int, textSize: Int, wallpaper: ChatWallpaper) {
        self.fill = fill
        self.bubbleRadius = bubbleRadius
        self.textSize = textSize
        self.wallpaper = wallpaper
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        fill = (try? container.decodeIfPresent(BubbleFill.self, forKey: .fill)) ?? fallback.fill
        bubbleRadius = (try? container.decodeIfPresent(Int.self, forKey: .bubbleRadius)) ?? fallback.bubbleRadius
        textSize = (try? container.decodeIfPresent(Int.self, forKey: .textSize)) ?? fallback.textSize
        wallpaper = (try? container.decodeIfPresent(ChatWallpaper.self, forKey: .wallpaper)) ?? fallback.wallpaper
        wallpaperColor = (try? container.decodeIfPresent(UInt32.self, forKey: .wallpaperColor)) ?? Self.defaultColor
    }
}
