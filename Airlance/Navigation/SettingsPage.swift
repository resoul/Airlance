enum SettingsPage: String, Sendable {
    case language
    case translationSkip
    case powerSaving
    case chatThemes
    case wallpapers
    case nightMode
    case textSize
    case bubbleCorners
    case editProfile
    case editUsername
    case authPreview

    var parents: [AppRoute] {
        switch self {
        case .translationSkip:
            [.settingsPage(.language)]
        case .chatThemes, .wallpapers, .nightMode, .textSize, .bubbleCorners:
            [.appearance]
        case .editUsername:
            [.settingsPage(.editProfile)]
        case .language, .powerSaving, .editProfile, .authPreview:
            []
        }
    }
}
