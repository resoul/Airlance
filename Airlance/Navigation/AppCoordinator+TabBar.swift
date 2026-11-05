import UIKit

extension AppCoordinator {
    func updateTabBarVisibility(
        for navigation: UINavigationController,
        top: UIViewController?,
        coordinator: (any UIViewControllerTransitionCoordinator)?
    ) {
        guard let index = tabNavigations.firstIndex(where: { tab in
            tab === navigation
        }), index == tabBarController.selectedIndex else {
            return
        }

        let isRoot = top == nil || top === navigation.viewControllers.first
        let topRoute = top.flatMap { controller in
            routes[ObjectIdentifier(controller)]
        }
        let hidesTabBar = tabs[index] == .settings || topRoute == .chatArchive || isFullScreenChat(topRoute)
        let hidden = !isRoot && hidesTabBar
        let leaving = coordinator?.viewController(forKey: .from).flatMap { controller in
            routes[ObjectIdentifier(controller)]
        }
        tabBarController.setTabBarHidden(
            hidden,
            animated: coordinator != nil,
            alongside: coordinator,
            slidesVertically: isProfileEditing(topRoute) || isProfileEditing(leaving)
        )
    }
}

extension AppCoordinator {
    fileprivate func isProfileEditing(_ route: AppRoute?) -> Bool {
        switch route {
        case .settingsPage(.editProfile), .settingsPage(.editUsername), .settingsPage(.editPhone):
            true
        default:
            false
        }
    }

    fileprivate func isFullScreenChat(_ route: AppRoute?) -> Bool {
        switch route {
        case .chat, .profile, .comments:
            true
        default:
            false
        }
    }
}
