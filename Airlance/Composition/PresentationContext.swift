import Localization
import Observers
import Theme

struct PresentationData: Sendable {
    let theme: AppTheme
    let strings: AppStrings
}

@MainActor
final class PresentationContext {
    private(set) var data: PresentationData

    private let observers = ObserverList<PresentationData>()
    private var observations: [ObservationToken] = []

    init(themeStore: ThemeStore, localizationStore: LocalizationStore) {
        data = PresentationData(theme: themeStore.theme, strings: AppStrings(pack: localizationStore.pack))

        observations = [
            themeStore.observe { [weak self] theme in
                self?.update(theme: theme)
            },
            localizationStore.observe { [weak self] pack in
                self?.update(pack: pack)
            },
        ]
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (PresentationData) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(data)

        return token
    }

    private func update(theme: AppTheme) {
        guard theme !== data.theme else {
            return
        }

        publish(PresentationData(theme: theme, strings: data.strings))
    }

    private func update(pack: LanguagePack) {
        guard pack !== data.strings.pack else {
            return
        }

        publish(PresentationData(theme: data.theme, strings: AppStrings(pack: pack)))
    }

    private func publish(_ data: PresentationData) {
        self.data = data
        observers.notify(data)
    }
}
