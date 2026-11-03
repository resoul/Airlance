import UIKit

extension AppCoordinator {
    func setUpDetail() {
        let placeholder = PlaceholderController(
            presentationSource: presentationContext,
            symbol: "bubble.left.and.bubble.right"
        ) { strings in
            strings.splitPlaceholder
        }
        let navigation = makeNavigation()
        navigation.viewControllers = [placeholder]
        detailPlaceholder = placeholder
        detailNavigation = navigation
        tabBarController.setDetail(navigation)
        tabBarController.onSplitChange = { [weak self] _ in
            self?.relayOutBase()
        }
    }

    var detailControllers: [UIViewController] {
        detailNavigation?.viewControllers.filter { controller in
            routes[ObjectIdentifier(controller)] != nil
        } ?? []
    }

    var visibleDetail: [UIViewController] {
        let tab = tabs.indices.contains(tabBarController.selectedIndex) ? tabs[tabBarController.selectedIndex] : nil

        return detailTab != nil && detailTab == tab ? detailControllers : []
    }

    func layOutBase(_ stack: [AppRoute], at index: Int, tabChanged: Bool, animated: Bool) {
        guard tabNavigations.indices.contains(index) else {
            return
        }

        let navigation = tabNavigations[index]
        let pool = navigation.viewControllers + detailControllers
        let kept = zip(pool, stack)
            .prefix { controller, route in
                routes[ObjectIdentifier(controller)] == route
            }
            .count
        let controllers = Array(pool.prefix(kept)) + stack.dropFirst(kept).map(makeScreen(for:))
        let split = tabBarController.isSplit ? (stack.firstIndex(where: \.isDetail) ?? stack.count) : stack.count
        let primary = Array(controllers.prefix(split))
        let detail = Array(controllers.dropFirst(split))
        if primary != navigation.viewControllers {
            let moving = primary.contains { controller in
                controller.navigationController === detailNavigation
            }
            if moving, let detailPlaceholder {
                detailNavigation?.setViewControllers([detailPlaceholder], animated: false)
            }
            navigation.setViewControllers(primary, animated: animated && !tabChanged)
        }
        if tabChanged || primary != navigation.viewControllers {
            updateTabBarVisibility(for: navigation, top: primary.last, coordinator: nil)
        }
        guard !(tabBarController.isSplit && detail.isEmpty && tabChanged) else {
            return
        }

        detailTab = detail.isEmpty ? nil : tabs[index]
        setDetail(detail, animated: animated)
    }

    private func setDetail(_ detail: [UIViewController], animated: Bool) {
        guard let detailNavigation, let detailPlaceholder else {
            return
        }

        let target = detail.isEmpty ? [detailPlaceholder] : detail
        let current = detailNavigation.viewControllers
        guard target != current else {
            return
        }

        let sameRoot = target.first === current.first
        detailNavigation.setViewControllers(target, animated: animated && sameRoot)
    }

    private func relayOutBase() {
        let stack = router.stack.prefix { route in
            route.presentation == .tab || route.presentation == .stack
        }
        let index = tabBarController.selectedIndex
        layOutBase(Array(stack), at: index, tabChanged: false, animated: false)
        if let navigation = selectedNavigation {
            updateTabBarVisibility(for: navigation, top: navigation.topViewController, coordinator: nil)
        }
    }
}
