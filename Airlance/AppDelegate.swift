import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private(set) lazy var context = makeContext()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        true
    }

    private func makeContext() -> ApplicationContext {
        do {
            return try ApplicationContext()
        } catch {
            fatalError("Can't open the shared storage: \(error)")
        }
    }
}
