import Database
import DatabaseAPI
import Foundation
import Keychain
import Localization
import Permissions
import Theme

@MainActor
final class AppEnvironment {
    let sharedStorage: any KeyValueStore
    let keychain: Keychain
    let themeStore: ThemeStore
    let localizationStore: LocalizationStore
    let presentationContext: PresentationContext
    let permissionStore: PermissionStore
    let permissionFlow: PermissionFlow
    let contactsSync: ContactsSync
    let account: AccountContext

    init(systemTraits: SystemTraits) throws {
        sharedStorage = try SharedStorage.open(directory: Self.sharedDirectory())
        keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "org.airlance")
        KeychainInstallation.prepare(keychain, storage: sharedStorage)
        themeStore = ThemeStore(storage: sharedStorage, systemTraits: systemTraits)
        localizationStore = LocalizationStore(
            storage: sharedStorage,
            configuration: .app,
            preferredLanguages: Locale.preferredLanguages
        )
        presentationContext = PresentationContext(themeStore: themeStore, localizationStore: localizationStore)
        permissionStore = PermissionStore(providers: AppPermissions.makeProviders())
        permissionFlow = PermissionFlow(store: permissionStore, presentationContext: presentationContext)
        contactsSync = ContactsSync(storage: sharedStorage, permissionStore: permissionStore)
        account = try AccountContext(accountID: Self.localAccountID, keychain: keychain)
    }

    private static let localAccountID = "local"

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
