import DatabaseAPI
import Observers

@MainActor
public final class ThemeStore {
    public private(set) var settings: ThemeSettings
    public private(set) var theme: AppTheme

    private let storage: any KeyValueStore
    private let observers = ObserverList<AppTheme>()
    private let settingsObservers = ObserverList<ThemeSettings>()
    private var systemTraits: SystemTraits
    private var settingsObservation: ObservationToken?

    public init(storage: any KeyValueStore, systemTraits: SystemTraits) {
        FontRegistry.registerBundledFonts()

        let settings = storage.value(for: .themeSettings)

        self.storage = storage
        self.systemTraits = systemTraits
        self.settings = settings
        theme = ThemeFactory.makeTheme(ThemeInputs(settings: settings, system: systemTraits))

        settingsObservation = storage.observe(.themeSettings) { [weak self] settings in
            self?.apply(settings: settings)
        }
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (AppTheme) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(theme)

        return token
    }

    public func observeSettings(
        _ onChange: @escaping @MainActor @Sendable (ThemeSettings) -> Void
    ) -> ObservationToken {
        let token = settingsObservers.add(onChange)
        onChange(settings)

        return token
    }

    public func setMode(_ mode: ThemeMode) async throws {
        try await storage.update(.themeSettings) {
            $0.mode = mode
        }
    }

    public func setAccent(_ accent: ThemeAccent) async throws {
        try await storage.update(.themeSettings) {
            $0.accent = accent
        }
    }

    public func setFont(_ font: ThemeFont) async throws {
        try await storage.update(.themeSettings) {
            $0.font = font
        }
    }

    public func updateSystemTraits(_ traits: SystemTraits) {
        guard traits != systemTraits else {
            return
        }

        systemTraits = traits
        rebuildTheme()
    }

    private func apply(settings: ThemeSettings) {
        guard settings != self.settings else {
            return
        }

        self.settings = settings
        settingsObservers.notify(settings)
        rebuildTheme()
    }

    private func rebuildTheme() {
        let inputs = ThemeInputs(settings: settings, system: systemTraits)
        guard inputs != theme.inputs else {
            return
        }

        theme = ThemeFactory.makeTheme(inputs)
        observers.notify(theme)
    }
}
