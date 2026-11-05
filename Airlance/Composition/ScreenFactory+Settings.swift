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
        case .editPhone:
            makePhoneEdit()
        case .powerSaving:
            makePowerSaving()
        case .stories:
            makeStorySettings()
        case .privacy, .blocked, .privacyPhone, .privacyPhotos, .privacyBio, .privacyMessages, .privacySearch:
            makePrivacy(page)
        }
    }

    private func makePrivacy(_ page: SettingsPage) -> UIViewController {
        let dependencies = PrivacyDependencies(
            presentationContext: scene.presentationContext,
            privacy: account.privacy
        )
        if page == .blocked {
            return BlockedListController(dependencies: dependencies)
        }

        guard let row = PrivacyRow.allCases.first(where: { row in
            row.page == page
        }) else {
            return PrivacyController(dependencies: dependencies, router: router)
        }

        return PrivacyOptionController(row: row, dependencies: dependencies)
    }

    private func makeStorySettings() -> UIViewController {
        StorySettingsController(
            dependencies: StorySettingsDependencies(
                presentationContext: scene.presentationContext,
                storage: account.storage
            )
        )
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
                store: account.myProfile,
                contacts: app.contactsSync.store,
                permissionFlow: scene.permissionFlow,
                videoNotes: account.videoNotes
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

    private func makePhoneEdit() -> UIViewController {
        PhoneEditController(
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
