import Observers
import Routing
import Theme
import UIKit

@MainActor
protocol AccountSwitching: AnyObject {
    var accountRecords: [AccountRecord] { get }
    var currentAccountID: AccountID? { get }

    func switchAccount(to id: AccountID)
    func retryAccount(_ id: AccountID)
    func addDemoAccount()
    func removeAccount(_ id: AccountID)
    func observeAccounts(_ onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken
}

@MainActor
final class SceneContext: AccountSwitching {
    private static let accountKey = "accountID"

    let app: ApplicationContext
    let window: UIWindow
    let sceneKey: String
    let theme: SceneTheme
    let presentationContext: PresentationContext
    let permissionFlow: PermissionFlow

    private let sceneSession: UISceneSession
    private let accountObservers = ObserverList<Void>()
    private var session: AccountSession?
    private var selectedID: AccountID?
    private var selection = 0
    private var scrollPositions: [AccountID: ChatScrollPositions] = [:]
    private var observation: ObservationToken?

    init(app: ApplicationContext, window: UIWindow, sceneSession: UISceneSession, traits: SystemTraits) {
        self.app = app
        self.window = window
        self.sceneSession = sceneSession
        sceneKey = sceneSession.persistentIdentifier
        theme = SceneTheme(store: app.themeStore, systemTraits: traits)
        presentationContext = PresentationContext(theme: theme, localizationStore: app.localizationStore)
        permissionFlow = PermissionFlow(store: app.permissionStore, presentationContext: presentationContext)
        observation = app.accounts.observe { [weak self] event in
            self?.handle(event)
        }
        let preferred = (sceneSession.userInfo?[Self.accountKey] as? String).map(AccountID.init(rawValue:))
        show(app.accounts.initialAccount(preferred: preferred))
    }

    var router: AppRouter? {
        session?.router
    }

    var accountRecords: [AccountRecord] {
        app.accounts.records
    }

    var currentAccountID: AccountID? {
        selectedID
    }

    func positions(for id: AccountID) -> ChatScrollPositions {
        if let positions = scrollPositions[id] {
            return positions
        }

        let positions = ChatScrollPositions()
        scrollPositions[id] = positions

        return positions
    }

    func updateTraits(_ traits: SystemTraits) {
        theme.updateSystemTraits(traits)
    }

    func open(_ route: ExternalRoute, animated: Bool) {
        if let accountID = route.accountID, accountID != selectedID {
            guard app.accounts.isAvailable(accountID) else {
                return
            }

            show(accountID)
        }
        if let path = route.path {
            session?.router.navigate(to: path, animated: animated && route.accountID == nil)
        }
    }

    func switchAccount(to id: AccountID) {
        guard id != selectedID else {
            return
        }

        perform { scene in
            scene.show(id)
        }
    }

    private func perform(_ action: @escaping @MainActor (SceneContext) -> Void) {
        let revision = selection
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selection == revision else {
                return
            }

            action(self)
        }
    }

    func retryAccount(_ id: AccountID) {
        perform { scene in
            scene.show(id)
        }
    }

    func addDemoAccount() {
        let record = app.accounts.addDemoAccount()
        switchAccount(to: record.id)
    }

    func removeAccount(_ id: AccountID) {
        perform { scene in
            let accounts = scene.app.accounts
            Task {
                await accounts.remove(id)
            }
        }
    }

    func observeAccounts(_ onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken {
        accountObservers.add { _ in
            onChange()
        }
    }

    private func handle(_ event: AccountEvent) {
        switch event {
        case .willRemove(let id):
            scrollPositions[id] = nil
            if selectedID == id {
                show(app.accounts.records.first { record in
                    record.id != id
                }?.id)
            }
        case .changed:
            if let selectedID, !app.accounts.isAvailable(selectedID) {
                show(app.accounts.initialAccount(preferred: nil))
            }
        }
        accountObservers.notify(())
    }

    private func show(_ id: AccountID?) {
        selection += 1
        session?.close()
        session = nil
        selectedID = id
        sceneSession.userInfo = id.map { id in
            [Self.accountKey: id.rawValue]
        }
        guard let id else {
            window.rootViewController = placeholder(failed: nil)

            return
        }

        switch app.accounts.context(for: id) {
        case .success(let account):
            app.accounts.select(id)
            session = AccountSession(account: account, scene: self, usage: app.accounts.use(id))
        case .failure(let failure):
            window.rootViewController = placeholder(failed: failure.accountID)
        }
        accountObservers.notify(())
    }

    private func placeholder(failed: AccountID?) -> UIViewController {
        AccountPlaceholderViewController(
            failedAccountID: failed,
            dependencies: AccountPlaceholderDependencies(presentationContext: presentationContext, accounts: self)
        )
    }
}

struct ExternalRoute {
    private static let scheme = "airlance"
    private static let accountHost = "account"

    let accountID: AccountID?
    let path: RoutePath?

    init?(url: URL) {
        guard url.scheme == Self.scheme else {
            return nil
        }

        guard url.host == Self.accountHost else {
            guard let path = RoutePath(url: url) else {
                return nil
            }

            accountID = nil
            self.path = path

            return
        }

        let components = url.path.split(separator: "/").map(String.init)
        guard let first = components.first else {
            return nil
        }

        accountID = AccountID(rawValue: first)
        path = components.count > 1 ? RoutePath(pathComponents: Array(components.dropFirst())) : nil
    }
}
