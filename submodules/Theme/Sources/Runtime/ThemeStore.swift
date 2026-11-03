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
            $0.night.schedule = mode == .system ? .system : .off
        }
    }

    public func setNight(_ night: NightSettings) async throws {
        try await storage.update(.themeSettings) {
            $0.night = night
        }
    }

    public func apply(_ preset: ChatThemePreset) async throws {
        try await storage.update(.themeSettings) {
            $0.accent = preset.accent
            $0.chat.wallpaper = preset.wallpaper
            $0.chat.fill = .gradient
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

    public func setChat(_ chat: ChatAppearance) async throws {
        try await storage.update(.themeSettings) {
            $0.chat = chat
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
