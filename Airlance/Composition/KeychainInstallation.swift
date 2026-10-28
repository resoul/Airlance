import DatabaseAPI
import Keychain
import os

extension StorageKey where Value == Bool {
    static let keychainInstalled = StorageKey("keychain.installed", default: false)
}

enum KeychainInstallation {
    private static let logger = Logger(subsystem: "Airlance", category: "Keychain")

    @MainActor
    static func prepare(_ keychain: Keychain, storage: any KeyValueStore) {
        guard !storage.value(for: .keychainInstalled) else {
            return
        }

        do {
            try keychain.removeAll()
        } catch {
            logger.error("Can't clear the keychain left from a previous install, retrying next launch: \(error)")

            return
        }

        Task {
            do {
                try await storage.update(.keychainInstalled) { value in
                    value = true
                }
            } catch {
                logger.error("Can't mark the keychain as installed: \(error)")
            }
        }
    }
}
