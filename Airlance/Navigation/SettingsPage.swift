enum SettingsPage: String, Sendable {
    case language
    case translationSkip
    case powerSaving
    case chatThemes
    case wallpapers
    case nightMode
    case textSize
    case bubbleCorners

    var parents: [AppRoute] {
        switch self {
        case .translationSkip:
            [.settingsPage(.language)]
        case .chatThemes, .wallpapers, .nightMode, .textSize, .bubbleCorners:
            [.appearance]
        case .language, .powerSaving:
            []
        }
    }
}
