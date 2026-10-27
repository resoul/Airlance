import Routing
import Theme
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private static let urlScheme = "airlance"

    var window: UIWindow?

    private var environment: SceneEnvironment?
    private var themeStore: ThemeStore?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard
            let windowScene = scene as? UIWindowScene,
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
        else {
            return
        }

        let app = appDelegate.environment
        app.themeStore.updateSystemTraits(SystemTraits(windowScene.traitCollection))

        let window = UIWindow(windowScene: windowScene)
        environment = SceneEnvironment(app: app, window: window)
        themeStore = app.themeStore
        self.window = window
        window.makeKeyAndVisible()

        open(connectionOptions.urlContexts, animated: false)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        open(URLContexts, animated: true)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: any UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        themeStore?.updateSystemTraits(SystemTraits(windowScene.traitCollection))
    }

    private func open(_ contexts: Set<UIOpenURLContext>, animated: Bool) {
        guard
            let url = contexts.first?.url,
            url.scheme == Self.urlScheme,
            let path = RoutePath(url: url)
        else {
            return
        }

        environment?.router.navigate(to: path, animated: animated)
    }
}
