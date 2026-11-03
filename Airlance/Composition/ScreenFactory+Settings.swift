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
        case .powerSaving:
            PowerSavingController(
                dependencies: PowerSavingDependencies(
                    presentationContext: scene.presentationContext,
                    powerSaving: app.powerSaving
                )
            )
        }
    }

    var appearanceDependencies: AppearanceDependencies {
        AppearanceDependencies(
            presentationContext: scene.presentationContext,
            themeStore: app.themeStore,
            videoNotes: account.videoNotes
        )
    }
}
