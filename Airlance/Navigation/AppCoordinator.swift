import Observers
import Routing
import UIKit

@MainActor
final class AppCoordinator: NSObject, RouteNavigator {
    private let window: UIWindow
    private let router: AppRouter
    private let factory: ScreenFactory
    private let navigationController = UINavigationController()
    private var routes: [ObjectIdentifier: AppRoute] = [:]
    private var presentationObservation: ObservationToken?

    init(window: UIWindow, router: AppRouter, factory: ScreenFactory) {
        self.window = window
        self.router = router
        self.factory = factory
        super.init()
    }

    func start(presentationContext: PresentationContext) {
        navigationController.delegate = self
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.viewControllers = [factory.makeChats()]
        window.rootViewController = navigationController
        router.attach(self)

        presentationObservation = presentationContext.observe { [weak self] data in
            self?.apply(data)
        }
    }

    func apply(_ transition: RouteTransition<AppRoute>, animated: Bool) {
        var controllers = navigationController.viewControllers
        controllers.removeLast(min(transition.popCount, controllers.count - 1))
        controllers += transition.push.map(makeScreen(for:))
        navigationController.setViewControllers(controllers, animated: animated)
    }

    private func makeScreen(for route: AppRoute) -> UIViewController {
        let controller = switch route {
        case .chat(let id):
            factory.makeChat(id: id)
        case .profile(let id):
            factory.makeProfile(id: id)
        case .settings:
            factory.makeSettings()
        }
        routes[ObjectIdentifier(controller)] = route

        return controller
    }

    private func apply(_ data: PresentationData) {
        let colors = data.theme.colors
        let fonts = data.theme.fonts

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.background
        appearance.shadowColor = colors.separator
        appearance.titleTextAttributes = [.foregroundColor: colors.textPrimary, .font: fonts.headline]
        appearance.largeTitleTextAttributes = [.foregroundColor: colors.textPrimary, .font: fonts.largeTitle]

        let navigationBar = navigationController.navigationBar
        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = colors.accent
        window.overrideUserInterfaceStyle = data.theme.appearance.userInterfaceStyle
    }
}

extension AppCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        let identifiers = navigationController.viewControllers.map { controller in
            ObjectIdentifier(controller)
        }
        routes = routes.filter { identifier, _ in
            identifiers.contains(identifier)
        }

        router.sync(identifiers.compactMap { identifier in
            routes[identifier]
        })
    }
}
