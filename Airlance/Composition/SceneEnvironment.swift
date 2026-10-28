import UIKit

@MainActor
final class SceneEnvironment {
    let router: AppRouter

    private let coordinator: AppCoordinator
    private let tabMemory: TabMemory

    init(app: AppEnvironment, window: UIWindow) {
        let tabMemory = TabMemory(storage: app.sharedStorage)
        let router = AppRouter(root: [tabMemory.tab])
        let factory = ScreenFactory(app: app, router: router)

        self.router = router
        self.tabMemory = tabMemory
        coordinator = AppCoordinator(
            window: window,
            router: router,
            factory: factory,
            presentationContext: app.presentationContext
        )
        coordinator.start()
        tabMemory.track(router)
    }
}
