import Observers
import UIKit

@MainActor
final class AccountSession {
    let account: AccountContext
    let router: AppRouter

    private let coordinator: AppCoordinator
    private let tabMemory: TabMemory
    private let quickReply: QuickReplyPresenter
    private var usage: ObservationToken?

    init(account: AccountContext, scene: SceneContext, usage: ObservationToken) {
        let tabMemory = TabMemory(
            storage: account.storage,
            scene: scene.sceneKey,
            legacy: account.accountID == .legacyLocal ? scene.app.sharedStorage : nil
        )
        let router = AppRouter(root: [tabMemory.tab])
        let factory = ScreenFactory(
            app: scene.app,
            scene: scene,
            account: account,
            positions: scene.positions(for: account.accountID),
            router: router
        )

        self.account = account
        self.router = router
        self.tabMemory = tabMemory
        self.usage = usage
        coordinator = AppCoordinator(
            window: scene.window,
            router: router,
            factory: factory,
            presentationContext: scene.presentationContext,
            accounts: scene
        )
        quickReply = QuickReplyPresenter(
            window: scene.window,
            historyStore: account.historyStore,
            presentationContext: scene.presentationContext,
            router: router
        )
        coordinator.start()
        tabMemory.track(router)
    }

    func close() {
        quickReply.close()
        coordinator.stop()
        usage = nil
    }
}
