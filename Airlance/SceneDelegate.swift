import Theme
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var context: SceneContext?

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

        let window = UIWindow(windowScene: windowScene)
        context = SceneContext(
            app: appDelegate.context,
            window: window,
            sceneSession: session,
            traits: SystemTraits(windowScene.traitCollection)
        )
        self.window = window
        window.makeKeyAndVisible()

        open(connectionOptions.urlContexts, animated: false)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        open(URLContexts, animated: true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        context = nil
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: any UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        context?.updateTraits(SystemTraits(windowScene.traitCollection))
    }

    private func open(_ contexts: Set<UIOpenURLContext>, animated: Bool) {
        guard let url = contexts.first?.url, let route = ExternalRoute(url: url) else {
            return
        }

        context?.open(route, animated: animated)
    }
}
