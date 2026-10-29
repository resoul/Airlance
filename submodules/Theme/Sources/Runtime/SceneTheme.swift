import Observers

@MainActor
public final class SceneTheme {
    public private(set) var theme: AppTheme

    private let observers = ObserverList<AppTheme>()
    private var settings: ThemeSettings
    private var systemTraits: SystemTraits
    private var settingsObservation: ObservationToken?

    public init(store: ThemeStore, systemTraits: SystemTraits) {
        settings = store.settings
        self.systemTraits = systemTraits
        theme = ThemeFactory.makeTheme(ThemeInputs(settings: store.settings, system: systemTraits))
        settingsObservation = store.observeSettings { [weak self] settings in
            self?.apply(settings: settings)
        }
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (AppTheme) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(theme)

        return token
    }

    public func updateSystemTraits(_ traits: SystemTraits) {
        guard traits != systemTraits else {
            return
        }

        systemTraits = traits
        rebuild()
    }

    private func apply(settings: ThemeSettings) {
        guard settings != self.settings else {
            return
        }

        self.settings = settings
        rebuild()
    }

    private func rebuild() {
        let inputs = ThemeInputs(settings: settings, system: systemTraits)
        guard inputs != theme.inputs else {
            return
        }

        theme = ThemeFactory.makeTheme(inputs)
        observers.notify(theme)
    }
}
