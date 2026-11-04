import UIKit

extension ScreenFactory {
    func makeSettingsPage(_ page: SettingsPage) -> UIViewController {
        switch page {
        case .language:
            LanguageViewController(
                dependencies: LanguageDependencies(
                    presentationContext: scene.presentationContext,
                    localizationStore: app.localizationStore,
                    translation: app.translation
                ),
                router: router
            )
        case .translationSkip:
            TranslationSkipController(
                dependencies: TranslationSkipDependencies(
                    presentationContext: scene.presentationContext,
                    translation: app.translation
                )
            )
        case .chatThemes:
            ChatThemesController(dependencies: appearanceDependencies)
        case .wallpapers:
            WallpapersController(dependencies: appearanceDependencies)
        case .nightMode:
            NightModeController(dependencies: appearanceDependencies)
        case .textSize:
            ChatMetricController(dependencies: appearanceDependencies, metric: .textSize)
        case .bubbleCorners:
            ChatMetricController(dependencies: appearanceDependencies, metric: .corners)
        case .editProfile:
            makeProfileEdit()
        case .editUsername:
            makeUsernameEdit()
        case .authPreview:
            AuthPreviewController(presentationContext: scene.presentationContext)
        case .powerSaving:
            makePowerSaving()
        }
    }

    private func makePowerSaving() -> UIViewController {
        PowerSavingController(
            dependencies: PowerSavingDependencies(
                presentationContext: scene.presentationContext,
                powerSaving: app.powerSaving
            )
        )
    }

    func makeChannelSettings(id: String, page: ChannelSettingsPage) -> UIViewController {
        let dependencies = ChannelSettingsDependencies(
            presentationContext: scene.presentationContext,
            chatsStore: account.chatsStore,
            settings: account.channelSettings,
            members: account.groupMembers,
            onAir: account.onAir
        )
        switch page {
        case .main:
            return ChannelSettingsController(id: id, dependencies: dependencies, router: router)
        case .type:
            return ChannelTypeController(id: id, dependencies: dependencies, router: router)
        case .subscribers, .admins, .banned:
            return ChannelMembersController(id: id, page: page, dependencies: dependencies)
        case .log:
            return ChannelLogController(
                id: id,
                store: account.channelSettings,
                presentationSource: scene.presentationContext
            )
        case .boosts:
            return ChannelBoostsController(id: id, dependencies: dependencies)
        case .appearance:
            return ChannelAppearanceController(id: id, dependencies: dependencies, router: router)
        }
    }

    private func makeProfileEdit() -> UIViewController {
        ProfileEditController(
            dependencies: ProfileEditDependencies(
                presentationContext: scene.presentationContext,
                store: account.myProfile
            ),
            router: router
        )
    }

    private func makeUsernameEdit() -> UIViewController {
        UsernameEditController(
            presentationSource: scene.presentationContext,
            store: account.myProfile,
            router: router
        )
    }

    var appearanceDependencies: AppearanceDependencies {
        AppearanceDependencies(
            presentationContext: scene.presentationContext,
            themeStore: app.themeStore,
            videoNotes: account.videoNotes
        )
    }
}
