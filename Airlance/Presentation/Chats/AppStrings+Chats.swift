import ChatFolders

extension AppStrings {
    func title(for category: ChatFolderCategory) -> String {
        switch category {
        case .contacts:
            chatsCategoryContacts
        case .nonContacts:
            chatsCategoryNonContacts
        case .groups:
            chatsCategoryGroups
        case .channels:
            chatsCategoryChannels
        case .bots:
            chatsCategoryBots
        }
    }

    func title(for exclusion: ChatFolderExclusion) -> String {
        switch exclusion {
        case .muted:
            chatsExclusionMuted
        case .read:
            chatsExclusionRead
        }
    }
}
