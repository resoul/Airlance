import UIKit

extension ScreenFactory {
    func makeOnAir() -> UIViewController {
        OnAirViewController(
            dependencies: OnAirDependencies(
                presentationContext: scene.presentationContext,
                store: account.onAir,
                chatsStore: account.chatsStore
            ),
            router: router
        )
    }

    func makeMyOnAir() -> UIViewController {
        MyOnAirController(
            dependencies: OnAirDependencies(
                presentationContext: scene.presentationContext,
                store: account.onAir,
                chatsStore: account.chatsStore
            ),
            router: router
        )
    }

    func makeTabSettings() -> UIViewController {
        TabSettingsController(
            dependencies: TabSettingsDependencies(
                presentationContext: scene.presentationContext,
                settings: account.tabs,
                accounts: scene
            )
        )
    }
}
