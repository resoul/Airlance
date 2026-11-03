import Foundation

extension AppStrings {
    func onAirTitle(_ section: OnAirSection) -> String {
        switch section {
        case .onAir:
            onAirSectionOnAir
        case .rising:
            onAirSectionRising
        case .new:
            onAirSectionNew
        case .news:
            onAirSectionNews
        }
    }

    func onAirTitle(_ category: OnAirCategory) -> String {
        switch category {
        case .tech:
            onAirCategoryTech
        case .design:
            onAirCategoryDesign
        case .news:
            onAirCategoryNews
        case .sport:
            onAirCategorySport
        case .music:
            onAirCategoryMusic
        case .science:
            onAirCategoryScience
        case .games:
            onAirCategoryGames
        }
    }

    func onAirSubscribers(_ value: Int) -> String {
        guard value >= 1000 else {
            return count(value, one: chatSubscribersOne, few: chatSubscribersFew, many: chatSubscribersMany)
        }

        return chatSubscribersMany(compactCount(value))
    }
}
