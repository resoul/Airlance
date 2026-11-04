import Auth
import Observers
import os
import Routing
import Theme
import ToastUI
import UIKit

@MainActor
protocol AccountSwitching: AnyObject {
    var accountRecords: [AccountRecord] { get }
    var currentAccountID: AccountID? { get }

    func switchAccount(to id: AccountID)
    func retryAccount(_ id: AccountID)
    func addDemoAccount()
    func addAccount()
    func removeAccount(_ id: AccountID)
    func observeAccounts(_ onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken
}

@MainActor
final class SceneContext: AccountSwitching {
    private static let accountKey = "accountID"
    private static let logger = Logger(subsystem: "Airlance", category: "Auth")

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
    private var showsGate = false
    private var isSigningIn = false
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

    func addAccount() {
        guard !isSigningIn else {
            return
        }

        isSigningIn = true
        let signIn = AuthWebSignIn(configuration: .airlance, anchor: window)
        Task { [weak self] in
            do {
                let result = try await signIn.start()
                try await self?.finishSignIn(result)
            } catch AuthError.cancelled {
                Self.logger.debug("Sign-in cancelled")
            } catch {
                self?.showSignInError(error)
            }
            self?.isSigningIn = false
        }
    }

    func revalidate() {
        guard
            let id = selectedID,
            let record = app.accounts.record(id),
            !record.isDemo,
            record.currentStatus == .active
        else {
            return
        }

        let auth = app.auth
        let accounts = app.accounts
        Task {
            do {
                _ = try await auth.validAccessToken(account: id.rawValue)
            } catch AuthError.sessionEnded {
                accounts.setStatus(.signedOut, for: id)
            } catch {
                Self.logger.error("Can't refresh the session: \(String(describing: error))")
            }
        }
    }

    private func finishSignIn(_ result: AuthSignIn) async throws {
        let id = AccountID.user(subject: result.subject)
        try await app.auth.save(result.tokens, account: id.rawValue)
        _ = app.accounts.addSignedIn(subject: result.subject, email: result.email)
        if selectedID != id {
            show(id)
        }
    }

    private func showSignInError(_ error: any Error) {
        let presentation = presentationContext.presentation
        let detail = (error as? AuthError)?.detail ?? error.localizedDescription
        Toast(presentation.strings.authSignInFailed(detail)).show(theme: presentation.theme, in: window)
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
            } else if let selectedID, gateNeeded(selectedID) != showsGate {
                show(selectedID)
            }
        }
        accountObservers.notify(())
    }

    private func show(_ id: AccountID?) {
        selection += 1
        session?.close()
        session = nil
        selectedID = id
        showsGate = false
        sceneSession.userInfo = id.map { id in
            [Self.accountKey: id.rawValue]
        }
        guard let id else {
            showWelcome()

            return
        }

        switch app.accounts.context(for: id) {
        case .success(let account):
            app.accounts.select(id)
            if showGate(for: id, account: account) {
                break
            }

            session = AccountSession(account: account, scene: self, usage: app.accounts.use(id))
            revalidate()
        case .failure(let failure):
            window.rootViewController = placeholder(failed: failure.accountID)
        }
        accountObservers.notify(())
    }

    private func gateNeeded(_ id: AccountID) -> Bool {
        app.accounts.record(id).map { record in
            record.currentStatus != .active
        } ?? false
    }

    private func showWelcome() {
        window.rootViewController = AuthGate.entry(
            step: .welcome,
            playsIntro: ParticleSplashView.claimFirstShow(),
            presentationContext: presentationContext,
            onContinue: { [weak self] in
                self?.addAccount()
            },
            onOther: nil
        )
    }

    private func showGate(for id: AccountID, account: AccountContext) -> Bool {
        switch app.accounts.record(id)?.currentStatus {
        case .signedOut:
            let other = app.accounts.records.first { record in
                record.id != id
            }?.id
            window.rootViewController = AuthGate.entry(
                step: .sessionEnded(canSwitch: other != nil),
                playsIntro: ParticleSplashView.claimFirstShow(),
                presentationContext: presentationContext,
                onContinue: { [weak self] in
                    self?.addAccount()
                },
                onOther: { [weak self] in
                    if let other {
                        self?.switchAccount(to: other)
                    }
                }
            )
        case .needsProfile:
            let accounts = app.accounts
            window.rootViewController = AuthGate.profile(presentationContext: presentationContext) { name, username in
                account.myProfile.update(MyProfile(name: name, username: username))
                accounts.setStatus(.active, for: id)
            }
        default:
            return false
        }
        showsGate = true

        return true
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
