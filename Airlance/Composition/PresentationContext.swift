import AirlanceUI
import Localization
import Observers
import Theme

struct PresentationData: ThemedPresentation {
    let theme: AppTheme
    let strings: AppStrings
}

@MainActor
final class PresentationContext: PresentationSource {
    private(set) var presentation: PresentationData

    private let observers = ObserverList<PresentationData>()
    private var observations: [ObservationToken] = []

    init(theme: SceneTheme, localizationStore: LocalizationStore) {
        presentation = PresentationData(theme: theme.theme, strings: AppStrings(pack: localizationStore.pack))

        observations = [
            theme.observe { [weak self] theme in
                self?.update(theme: theme)
            },
            localizationStore.observe { [weak self] pack in
                self?.update(pack: pack)
            },
        ]
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (PresentationData) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(presentation)

        return token
    }

    private func update(theme: AppTheme) {
        guard theme !== presentation.theme else {
            return
        }

        publish(PresentationData(theme: theme, strings: presentation.strings))
    }

    private func update(pack: LanguagePack) {
        guard pack !== presentation.strings.pack else {
            return
        }

        publish(PresentationData(theme: presentation.theme, strings: AppStrings(pack: pack)))
    }

    private func publish(_ presentation: PresentationData) {
        self.presentation = presentation
        observers.notify(presentation)
    }
}
