import DatabaseAPI
import Observers

@MainActor
public final class LocalizationStore {
    public private(set) var settings: LanguageSettings
    public private(set) var pack: LanguagePack

    private let storage: any KeyValueStore
    private let configuration: LocalizationConfiguration
    private let preferredLanguages: [String]
    private let observers = ObserverList<LanguagePack>()
    private var settingsObservation: ObservationToken?

    public var languages: [LanguageCode] {
        configuration.languages
    }

    public init(
        storage: any KeyValueStore,
        configuration: LocalizationConfiguration,
        preferredLanguages: [String]
    ) {
        let settings = storage.value(for: .languageSettings)
        let language = LanguageResolver.language(
            for: settings,
            configuration: configuration,
            preferredLanguages: preferredLanguages
        )

        self.storage = storage
        self.configuration = configuration
        self.preferredLanguages = preferredLanguages
        self.settings = settings
        pack = LanguagePackLoader.load(language, configuration: configuration)

        settingsObservation = storage.observe(.languageSettings) { [weak self] settings in
            self?.apply(settings: settings)
        }
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (LanguagePack) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(pack)

        return token
    }

    public func select(_ selection: LanguageSelection) async throws {
        try await storage.update(.languageSettings) {
            $0.selection = selection
        }
    }

    private func apply(settings: LanguageSettings) {
        guard settings != self.settings else {
            return
        }

        self.settings = settings
        rebuildPack()
    }

    private func rebuildPack() {
        let language = LanguageResolver.language(
            for: settings,
            configuration: configuration,
            preferredLanguages: preferredLanguages
        )
        guard language != pack.language else {
            return
        }

        pack = LanguagePackLoader.load(language, configuration: configuration)
        observers.notify(pack)
    }
}
