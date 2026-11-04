import Auth
import Database
import DatabaseAPI
import Foundation
import Keychain
import Localization
import MediaLoader
import MediaStore
import Permissions
import Theme

@MainActor
final class ApplicationContext {
    nonisolated static let thumbnailLimit: Int64 = 200 * 1024 * 1024

    let sharedStorage: any KeyValueStore
    let keychain: Keychain
    let auth: AuthTokenStore
    let servers: AccountServers
    let themeStore: ThemeStore
    let localizationStore: LocalizationStore
    let permissionStore: PermissionStore
    let contactsSync: ContactsSync
    let accounts: AccountManager
    let translation: TranslationSettings
    let powerSaving: PowerSaving

    init() throws {
        MediaRenderer.generatedArt = { seed, size in
            StoryArt.render(seed: seed, size: size)
        }
        Task.detached(priority: .background) {
            MediaStore.removeLegacyFolders()
            MediaDiskCache.shared.trim(to: Self.thumbnailLimit)
        }
        sharedStorage = try SharedStorage.open(directory: Self.sharedDirectory())
        keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "org.airlance")
        KeychainInstallation.prepare(keychain, storage: sharedStorage)
        themeStore = ThemeStore(storage: sharedStorage)
        localizationStore = LocalizationStore(
            storage: sharedStorage,
            configuration: .app,
            preferredLanguages: Locale.preferredLanguages
        )
        permissionStore = PermissionStore(providers: AppPermissions.makeProviders())
        contactsSync = ContactsSync(storage: sharedStorage, permissionStore: permissionStore)
        auth = AuthTokenStore(configuration: .airlance, keychain: keychain)
        servers = AccountServers(auth: auth)
        accounts = AccountManager(storage: sharedStorage, keychain: keychain, auth: auth)
        translation = TranslationSettings(storage: sharedStorage)
        powerSaving = PowerSaving(storage: sharedStorage)
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

extension AuthConfiguration {
    static let airlance = AuthConfiguration(
        issuer: "https://auth.airlance.org",
        clientID: "airlance-ios",
        redirectScheme: "airlance",
        redirectURI: "airlance://auth/callback",
        scope: "openid email profile:read profile:write",
        resource: "https://api.airlance.org"
    )
}
