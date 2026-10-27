import Theme
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private(set) lazy var environment = makeEnvironment()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        true
    }

    private func makeEnvironment() -> AppEnvironment {
        let systemTraits = SystemTraits(UITraitCollection.current)

        do {
            return try AppEnvironment(systemTraits: systemTraits)
        } catch {
            fatalError("Can't open the shared storage: \(error)")
        }
    }
}
