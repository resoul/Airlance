import UIKit

@MainActor
final class ScreenFactory {
    private let app: AppEnvironment
    private let router: AppRouter

    init(app: AppEnvironment, router: AppRouter) {
        self.app = app
        self.router = router
    }

    func makeChats() -> UIViewController {
        ChatsViewController(
            dependencies: ChatsDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeChat(id: Int) -> UIViewController {
        ChatViewController(
            id: id,
            dependencies: ChatDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeMedia(id: Int) -> UIViewController {
        MediaViewController(
            id: id,
            dependencies: MediaDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeNewChat() -> UIViewController {
        NewChatViewController(
            dependencies: NewChatDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeProfile(id: Int) -> UIViewController {
        ProfileViewController(
            id: id,
            dependencies: ProfileDependencies(presentationContext: app.presentationContext),
            router: router
        )
    }

    func makeSettings() -> UIViewController {
        SettingsViewController(
            dependencies: SettingsDependencies(
                presentationContext: app.presentationContext,
                themeStore: app.themeStore,
                localizationStore: app.localizationStore
            )
        )
    }
}
