public enum ChatThemePreset: String, CaseIterable, Sendable {
    case home
    case spring
    case winter
    case gem
    case school
    case tulip
    case love
    case holiday
    case game

    public var emoji: String {
        switch self {
        case .home:
            "🏠"
        case .spring:
            "🐥"
        case .winter:
            "⛄️"
        case .gem:
            "💎"
        case .school:
            "📐"
        case .tulip:
            "🌷"
        case .love:
            "💜"
        case .holiday:
            "🎄"
        case .game:
            "🎮"
        }
    }

    public var accent: ThemeAccent {
        switch self {
        case .home:
            .blue
        case .spring:
            .green
        case .winter:
            .teal
        case .gem:
            .violet
        case .school:
            .indigo
        case .tulip:
            .orange
        case .love:
            .pink
        case .holiday:
            .red
        case .game:
            .indigo
        }
    }

    public var wallpaper: ChatWallpaper {
        switch self {
        case .home:
            .aurora
        case .spring:
            .mint
        case .winter:
            .frost
        case .gem:
            .night
        case .school:
            .school
        case .tulip:
            .sunset
        case .love:
            .love
        case .holiday:
            .holiday
        case .game:
            .games
        }
    }

    public func matches(_ settings: ThemeSettings) -> Bool {
        settings.accent == accent && settings.chat.wallpaper == wallpaper && settings.chat.fill == .gradient
    }
}
