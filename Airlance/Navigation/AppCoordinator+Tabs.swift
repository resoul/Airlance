import AirlanceUI
import UIKit

extension AppCoordinator {
    func setUpTabs() {
        tabs = tabSettings.tabs
        router.tabs = tabs
        if let current = router.tab, !tabs.contains(current) {
            router.sync([.chats])
        }
        tabNavigations = tabs.map(makeTabNavigation(for:))
        tabBarController.setTabs(
            tabNavigations,
            items: makeTabItems(presentationContext.presentation),
            selectedIndex: router.tab.flatMap(tabs.firstIndex(of:)) ?? 0
        )
    }

    func updateTabs(_ newTabs: [AppRoute]) {
        guard newTabs != tabs else {
            return
        }

        let current = router.tab
        let reused = Dictionary(uniqueKeysWithValues: zip(tabs, tabNavigations))
        tabs = newTabs
        router.tabs = newTabs
        tabNavigations = newTabs.map { tab in
            reused[tab] ?? makeTabNavigation(for: tab)
        }
        let index = current.flatMap(newTabs.firstIndex(of:))
        tabBarController.setTabs(
            tabNavigations,
            items: makeTabItems(presentationContext.presentation),
            selectedIndex: index ?? newTabs.firstIndex(of: .chats) ?? 0
        )
        if index == nil {
            router.selectTab(.chats, animated: false)
        }
    }

    func makeTabItems(_ presentation: PresentationData) -> [TabBarItem] {
        AppTabItems.make(tabs, presentation: presentation, accounts: accounts)
    }

    private func makeTabNavigation(for tab: AppRoute) -> ScreenNavigationController {
        let navigation = makeNavigation(prefersLargeTitles: true)
        navigation.viewControllers = [makeScreen(for: tab)]

        return navigation
    }
}
