import Database
import DatabaseAPI
import Foundation
import Localization
import Theme

@MainActor
final class AppEnvironment {
    let sharedStorage: any KeyValueStore
    let themeStore: ThemeStore
    let localizationStore: LocalizationStore
    let presentationContext: PresentationContext

    init(systemTraits: SystemTraits) throws {
        sharedStorage = try SharedStorage.open(directory: Self.sharedDirectory())
        themeStore = ThemeStore(storage: sharedStorage, systemTraits: systemTraits)
        localizationStore = LocalizationStore(
            storage: sharedStorage,
            configuration: .app,
            preferredLanguages: Locale.preferredLanguages
        )
        presentationContext = PresentationContext(themeStore: themeStore, localizationStore: localizationStore)
    }

    private static func sharedDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport.appendingPathComponent("Shared", isDirectory: true)
    }
}
