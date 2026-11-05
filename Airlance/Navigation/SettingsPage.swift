enum SettingsPage: String, Sendable {
    case language
    case translationSkip
    case powerSaving
    case stories
    case privacy
    case blocked
    case privacyPhone
    case privacyPhotos
    case privacyBio
    case privacyMessages
    case privacySearch
    case agents
    case agentEdit
    case agentRuns
    case chatThemes
    case wallpapers
    case nightMode
    case textSize
    case bubbleCorners
    case editProfile
    case editUsername
    case editPhone

    var parents: [AppRoute] {
        switch self {
        case .translationSkip:
            [.settingsPage(.language)]
        case .chatThemes, .wallpapers, .nightMode, .textSize, .bubbleCorners:
            [.appearance]
        case .editUsername, .editPhone:
            [.settingsPage(.editProfile)]
        case .blocked, .privacyPhone, .privacyPhotos, .privacyBio, .privacyMessages, .privacySearch:
            [.settingsPage(.privacy)]
        case .agentEdit:
            [.settingsPage(.agents)]
        case .agentRuns:
            [.settingsPage(.agents), .settingsPage(.agentEdit)]
        case .language, .powerSaving, .stories, .privacy, .editProfile, .agents:
            []
        }
    }
}
