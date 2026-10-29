import DatabaseAPI
import Observers

@MainActor
public final class ThemeStore {
    public private(set) var settings: ThemeSettings

    private let storage: any KeyValueStore
    private let settingsObservers = ObserverList<ThemeSettings>()
    private var settingsObservation: ObservationToken?

    public init(storage: any KeyValueStore) {
        FontRegistry.registerBundledFonts()

        self.storage = storage
        settings = storage.value(for: .themeSettings)

        settingsObservation = storage.observe(.themeSettings) { [weak self] settings in
            self?.apply(settings: settings)
        }
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

    private func apply(settings: ThemeSettings) {
        guard settings != self.settings else {
            return
        }

        self.settings = settings
        settingsObservers.notify(settings)
    }
}
