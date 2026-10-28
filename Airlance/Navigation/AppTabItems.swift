import AirlanceUI
import UIKit

@MainActor
enum AppTabItems {
    static func make(_ strings: AppStrings) -> [TabBarItem] {
        AppRoute.tabs.map { tab in
            switch tab {
            case .contacts:
                TabBarItem(
                    image: UIImage(systemName: "person.crop.circle"),
                    selectedImage: UIImage(systemName: "person.crop.circle.fill"),
                    title: strings.tabContacts
                )
            case .chats:
                TabBarItem(
                    image: UIImage(systemName: "bubble.left.and.bubble.right"),
                    selectedImage: UIImage(systemName: "bubble.left.and.bubble.right.fill"),
                    title: strings.tabChats
                )
            case .calls:
                TabBarItem(
                    image: UIImage(systemName: "phone"),
                    selectedImage: UIImage(systemName: "phone.fill"),
                    title: strings.tabCalls
                )
            default:
                TabBarItem(
                    image: UIImage(systemName: "gearshape"),
                    selectedImage: UIImage(systemName: "gearshape.fill"),
                    title: strings.tabSettings
                )
            }
        }
    }

    static func menu(for index: Int, strings: AppStrings, router: AppRouter) -> [PopupMenuItem]? {
        guard AppRoute.tabs.indices.contains(index) else {
            return nil
        }

        switch AppRoute.tabs[index] {
        case .chats:
            let addFolder = PopupMenuItem(title: strings.tabsChatsAddFolder, symbol: "folder.badge.plus") {
                router.selectTab(.chats)
                router.open(.newChatFolder)
            }

            return [addFolder]
        default:
            return nil
        }
    }
}
