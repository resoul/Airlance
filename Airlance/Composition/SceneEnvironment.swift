import UIKit

@MainActor
final class SceneEnvironment {
    let router: AppRouter

    private let coordinator: AppCoordinator

    init(app: AppEnvironment, window: UIWindow) {
        let router = AppRouter()
        let factory = ScreenFactory(app: app, router: router)

        self.router = router
        coordinator = AppCoordinator(window: window, router: router, factory: factory)
        coordinator.start(presentationContext: app.presentationContext)
    }
}
