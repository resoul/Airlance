import AirlanceUI
import Observers
import Routing
import Stories
import UIKit

@MainActor
final class AppCoordinator: NSObject, RouteNavigator {
    private typealias Completion = @MainActor @Sendable () -> Void

    private struct PendingTransition {
        let transition: RouteTransition<AppRoute>
        let animated: Bool
    }

    private let window: UIWindow
    private let router: AppRouter
    private let factory: ScreenFactory
    private let presentationContext: PresentationContext
    private let tabBarController: ScreenTabBarController
    private var tabNavigations: [ScreenNavigationController] = []
    private var modalNavigations: [ScreenNavigationController] = []
    private var routes: [ObjectIdentifier: AppRoute] = [:]
    private var pending: [PendingTransition] = []
    private var isApplying = false
    private var presentationObservation: ObservationToken?

    private var selectedNavigation: ScreenNavigationController? {
        let index = tabBarController.selectedIndex

        return tabNavigations.indices.contains(index) ? tabNavigations[index] : nil
    }

    init(window: UIWindow, router: AppRouter, factory: ScreenFactory, presentationContext: PresentationContext) {
        self.window = window
        self.router = router
        self.factory = factory
        self.presentationContext = presentationContext
        tabBarController = ScreenTabBarController(presentationSource: presentationContext)
        super.init()
    }

    func start() {
        tabNavigations = AppRoute.tabs.map { tab in
            let navigation = makeNavigation(prefersLargeTitles: true)
            navigation.viewControllers = [makeScreen(for: tab)]

            return navigation
        }
        let selectedIndex = router.tab.flatMap(AppRoute.tabs.firstIndex(of:)) ?? 0
        tabBarController.setTabs(
            tabNavigations,
            items: AppTabItems.make(presentationContext.presentation.strings),
            selectedIndex: selectedIndex
        )
        tabBarController.onSelect = { [weak self] index in
            self?.selectTab(at: index)
        }
        tabBarController.menuProvider = { [weak self] index in
            guard let self else {
                return nil
            }

            return AppTabItems.menu(for: index, strings: presentationContext.presentation.strings, router: router)
        }
        window.rootViewController = tabBarController
        router.attach(self)

        presentationObservation = presentationContext.observe { [weak self] presentation in
            self?.apply(presentation)
        }
    }

    func apply(_ transition: RouteTransition<AppRoute>, animated: Bool) {
        pending.append(PendingTransition(transition: transition, animated: animated))
        applyNext()
    }

    private func selectTab(at index: Int) {
        let tab = AppRoute.tabs[index]
        guard router.stack != [tab] else {
            tabBarController.scrollSelectedToTop()

            return
        }

        router.selectTab(tab)
    }

    private func applyNext() {
        guard !isApplying else {
            return
        }

        guard !pending.isEmpty else {
            syncRouter()

            return
        }

        let next = pending.removeFirst()
        isApplying = true
        run(next.transition, animated: next.animated) { [weak self] in
            self?.isApplying = false
            self?.applyNext()
        }
    }

    private func run(_ transition: RouteTransition<AppRoute>, animated: Bool, completion: @escaping Completion) {
        dismissLayers(count: transition.dismissCount, animated: animated) { [weak self] in
            guard let self else {
                return
            }

            let animatedUpdate = animated && transition.present.isEmpty
            if let update = transition.update {
                if update.index == 0, let base = transition.layers.first {
                    self.updateBase(base, animated: animatedUpdate)
                } else {
                    self.updateModal(update, animated: animatedUpdate)
                }
            }
            self.present(transition.present[...], animated: animated, completion: completion)
        }
    }

    private func dismissLayers(count: Int, animated: Bool, completion: @escaping Completion) {
        let count = min(count, modalNavigations.count)
        guard count > 0 else {
            completion()

            return
        }

        let first = modalNavigations[modalNavigations.count - count]
        modalNavigations.removeLast(count)
        guard let presenting = first.presentingViewController else {
            completion()

            return
        }

        presenting.dismiss(animated: animated, completion: completion)
    }

    private func updateBase(_ layer: RouteLayer<AppRoute>, animated: Bool) {
        guard let tab = layer.routes.first, let index = AppRoute.tabs.firstIndex(of: tab) else {
            return
        }

        let tabChanged = index != tabBarController.selectedIndex
        tabBarController.select(index, animated: animated)

        let navigation = tabNavigations[index]
        let current = navigation.viewControllers
        let kept = zip(current, layer.routes)
            .prefix { controller, route in
                routes[ObjectIdentifier(controller)] == route
            }
            .count
        let controllers = Array(current.prefix(kept)) + layer.routes.dropFirst(kept).map(makeScreen(for:))
        guard controllers != current else {
            return
        }

        navigation.setViewControllers(controllers, animated: animated && !tabChanged)
        if tabChanged {
            updateTabBarVisibility(for: navigation, top: controllers.last, coordinator: nil)
        }
    }

    private func updateModal(_ update: RouteLayerUpdate<AppRoute>, animated: Bool) {
        let index = update.index - 1
        guard modalNavigations.indices.contains(index) else {
            return
        }

        let navigation = modalNavigations[index]
        var controllers = navigation.viewControllers
        controllers.removeLast(min(update.popCount, controllers.count - 1))
        controllers += update.push.map(makeScreen(for:))
        navigation.setViewControllers(controllers, animated: animated)
    }

    private func present(
        _ layers: ArraySlice<RouteLayer<AppRoute>>,
        animated: Bool,
        completion: @escaping Completion
    ) {
        guard let layer = layers.first else {
            completion()

            return
        }

        let presenting: UIViewController = modalNavigations.last ?? tabBarController
        let navigation = makeNavigation(for: layer)
        modalNavigations.append(navigation)
        presenting.present(navigation, animated: animated) { [weak self] in
            self?.present(layers.dropFirst(), animated: animated, completion: completion)
        }
    }

    private func makeNavigation(prefersLargeTitles: Bool = false) -> ScreenNavigationController {
        let navigation = ScreenNavigationController(
            presentationSource: presentationContext,
            prefersLargeTitles: prefersLargeTitles
        )
        navigation.delegate = self

        return navigation
    }

    private func makeNavigation(for layer: RouteLayer<AppRoute>) -> ScreenNavigationController {
        let navigation = makeNavigation()
        navigation.viewControllers = layer.routes.map(makeScreen(for:))
        navigation.viewControllers.first?.navigationItem.leftBarButtonItem = makeCloseItem()

        switch layer.presentation {
        case .stack, .tab:
            break
        case .sheet:
            navigation.modalPresentationStyle = .pageSheet
            let resizable = layer.routes.first == .newChat
            navigation.sheetPresentationController?.detents = resizable ? [.medium(), .large()] : [.large()]
            navigation.sheetPresentationController?.prefersGrabberVisible = true
        case .fullScreen:
            navigation.modalPresentationStyle = .fullScreen
        }
        if let viewer = navigation.viewControllers.first as? StoryViewerController {
            viewer.install(in: navigation, source: selectedNavigation?.topViewController as? StoryTransitionSource)
        }
        navigation.presentationController?.delegate = self

        return navigation
    }

    private func makeScreen(for route: AppRoute) -> UIViewController {
        let controller = switch route {
        case .contacts:
            factory.makeContacts()
        case .chats:
            factory.makeChats()
        case .calls:
            factory.makeCalls()
        case .settings:
            factory.makeSettings()
        case .chat(let id):
            factory.makeChat(id: id)
        case .media(let id):
            factory.makeMedia(id: id)
        case .newChat:
            factory.makeNewChat()
        case .newContact:
            factory.makeNewContact()
        case .invite:
            factory.makeInvite()
        case .permissions:
            factory.makePermissions()
        case .appearance:
            factory.makeAppearance()
        case .profile(let id):
            factory.makeProfile(id: id)
        case .stories(let peerID):
            factory.makeStories(peerID: peerID)
        case .chatFolders:
            factory.makeChatFolders()
        case .newChatFolder:
            factory.makeChatFolderEditor(id: nil)
        case .chatFolder(let id):
            factory.makeChatFolderEditor(id: id)
        }
        routes[ObjectIdentifier(controller)] = route

        return controller
    }

    private func syncRouter() {
        guard !isApplying, pending.isEmpty, let selectedNavigation else {
            return
        }

        let identifiers = Set((tabNavigations + modalNavigations).flatMap(\.viewControllers).map(ObjectIdentifier.init))
        routes = routes.filter { identifier, _ in
            identifiers.contains(identifier)
        }

        let visible = ([selectedNavigation] + modalNavigations).flatMap(\.viewControllers)
        router.sync(visible.compactMap { controller in
            routes[ObjectIdentifier(controller)]
        })
    }
}

extension AppCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        updateTabBarVisibility(
            for: navigationController,
            top: viewController,
            coordinator: animated ? navigationController.transitionCoordinator : nil
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        syncRouter()
        tabBarController.updateTrackedScrollView()
    }
}

extension AppCoordinator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let index = modalNavigations.firstIndex { navigation in
            navigation === presentationController.presentedViewController
        }
        guard let index else {
            return
        }

        modalNavigations.removeSubrange(index...)
        syncRouter()
    }
}

extension AppCoordinator {
    fileprivate func updateTabBarVisibility(
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
        let hidden = AppRoute.tabs[index] == .settings && !isRoot
        tabBarController.setTabBarHidden(hidden, animated: coordinator != nil, alongside: coordinator)
    }
}

extension AppCoordinator {
    fileprivate func makeCloseItem() -> UIBarButtonItem {
        UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [router] _ in
                router.dismiss()
            }
        )
    }

    fileprivate func apply(_ presentation: PresentationData) {
        tabBarController.setItems(AppTabItems.make(presentation.strings))
        window.overrideUserInterfaceStyle = presentation.theme.appearance.userInterfaceStyle
    }
}
