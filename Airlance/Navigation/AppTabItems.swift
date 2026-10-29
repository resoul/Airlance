import AirlanceUI
import UIKit

@MainActor
enum AppTabItems {
    private static let avatarSide: CGFloat = 28

    static func make(_ presentation: PresentationData, accounts: any AccountSwitching) -> [TabBarItem] {
        let strings = presentation.strings

        return AppRoute.tabs.map { tab in
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
                settingsItem(presentation, accounts: accounts)
            }
        }
    }

    static func menu(
        for index: Int,
        strings: AppStrings,
        router: AppRouter,
        accounts: any AccountSwitching
    ) -> [PopupMenuItem]? {
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
        case .settings:
            return accountItems(strings: strings, accounts: accounts)
        default:
            return nil
        }
    }

    private static func settingsItem(_ presentation: PresentationData, accounts: any AccountSwitching) -> TabBarItem {
        let strings = presentation.strings
        let current = accounts.accountRecords.first { record in
            record.id == accounts.currentAccountID
        }
        guard accounts.accountRecords.count > 1, let current else {
            return TabBarItem(
                image: UIImage(systemName: "gearshape"),
                selectedImage: UIImage(systemName: "gearshape.fill"),
                title: strings.tabSettings
            )
        }

        return TabBarItem(
            image: AccountAvatars.image(current, strings: strings, side: avatarSide),
            selectedImage: AccountAvatars.ringed(
                current,
                strings: strings,
                side: avatarSide + 4,
                ring: presentation.theme.colors.onAccent
            ),
            title: strings.tabSettings
        )
    }

    private static func accountItems(strings: AppStrings, accounts: any AccountSwitching) -> [PopupMenuItem] {
        var items: [PopupMenuItem] = []
        if accounts.accountRecords.count > 1 {
            items = accounts.accountRecords.map { record in
                let id = record.id

                return PopupMenuItem(
                    title: strings.accountName(record),
                    image: AccountAvatars.image(record, strings: strings, side: avatarSide),
                    isChecked: id == accounts.currentAccountID
                ) {
                    accounts.switchAccount(to: id)
                }
            }
        }
        items.append(PopupMenuItem(title: strings.accountAdd, symbol: "plus.circle") {
            accounts.addDemoAccount()
        })

        return items
    }
}
