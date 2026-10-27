import Observers
import Routing
import Theme
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
    private let rootNavigation = UINavigationController()
    private var modalNavigations: [UINavigationController] = []
    private var routes: [ObjectIdentifier: AppRoute] = [:]
    private var pending: [PendingTransition] = []
    private var isApplying = false
    private var theme: AppTheme?
    private var presentationObservation: ObservationToken?

    private var navigations: [UINavigationController] {
        [rootNavigation] + modalNavigations
    }

    init(window: UIWindow, router: AppRouter, factory: ScreenFactory) {
        self.window = window
        self.router = router
        self.factory = factory
        super.init()
    }

    func start(presentationContext: PresentationContext) {
        setUp(rootNavigation)
        rootNavigation.navigationBar.prefersLargeTitles = true
        rootNavigation.viewControllers = [factory.makeChats()]
        window.rootViewController = rootNavigation
        router.attach(self)

        presentationObservation = presentationContext.observe { [weak self] data in
            self?.apply(data.theme)
        }
    }

    func apply(_ transition: RouteTransition<AppRoute>, animated: Bool) {
        pending.append(PendingTransition(transition: transition, animated: animated))
        applyNext()
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

            if let update = transition.update {
                self.update(update, animated: animated && transition.present.isEmpty)
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

    private func update(_ update: RouteLayerUpdate<AppRoute>, animated: Bool) {
        guard update.index < navigations.count else {
            return
        }

        let navigation = navigations[update.index]
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
        guard let layer = layers.first, let presenting = navigations.last else {
            completion()

            return
        }

        let navigation = makeNavigation(for: layer)
        modalNavigations.append(navigation)
        presenting.present(navigation, animated: animated) { [weak self] in
            self?.present(layers.dropFirst(), animated: animated, completion: completion)
        }
    }

    private func makeNavigation(for layer: RouteLayer<AppRoute>) -> UINavigationController {
        let navigation = UINavigationController()
        setUp(navigation)
        navigation.viewControllers = layer.routes.map(makeScreen(for:))
        navigation.viewControllers.first?.navigationItem.leftBarButtonItem = makeCloseItem()

        switch layer.presentation {
        case .stack:
            break
        case .sheet:
            navigation.modalPresentationStyle = .pageSheet
            navigation.sheetPresentationController?.detents = [.medium(), .large()]
            navigation.sheetPresentationController?.prefersGrabberVisible = true
        case .fullScreen:
            navigation.modalPresentationStyle = .fullScreen
        }
        navigation.presentationController?.delegate = self

        return navigation
    }

    private func makeCloseItem() -> UIBarButtonItem {
        UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [router] _ in
                router.dismiss()
            }
        )
    }

    private func makeScreen(for route: AppRoute) -> UIViewController {
        let controller = switch route {
        case .chat(let id):
            factory.makeChat(id: id)
        case .media(let id):
            factory.makeMedia(id: id)
        case .newChat:
            factory.makeNewChat()
        case .profile(let id):
            factory.makeProfile(id: id)
        case .settings:
            factory.makeSettings()
        }
        routes[ObjectIdentifier(controller)] = route

        return controller
    }

    private func setUp(_ navigation: UINavigationController) {
        navigation.delegate = self
        if let theme {
            navigation.apply(theme)
        }
    }

    private func syncRouter() {
        guard !isApplying, pending.isEmpty else {
            return
        }

        let controllers = navigations.flatMap(\.viewControllers)
        let identifiers = Set(controllers.map(ObjectIdentifier.init))
        routes = routes.filter { identifier, _ in
            identifiers.contains(identifier)
        }

        router.sync(controllers.compactMap { controller in
            routes[ObjectIdentifier(controller)]
        })
    }

    private func apply(_ theme: AppTheme) {
        self.theme = theme
        for navigation in navigations {
            navigation.apply(theme)
        }
        window.overrideUserInterfaceStyle = theme.appearance.userInterfaceStyle
    }
}

extension AppCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        syncRouter()
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
