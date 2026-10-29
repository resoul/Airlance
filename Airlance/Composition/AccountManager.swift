import DatabaseAPI
import Foundation
import Keychain
import Observers
import os

enum AccountEvent: Sendable {
    case changed
    case willRemove(AccountID)
}

struct AccountOpenFailure: Error, Sendable {
    let accountID: AccountID
    let message: String
}

extension StorageKey where Value == [String] {
    static let removingAccounts = StorageKey("accounts.removing", default: [])
}

@MainActor
final class AccountManager {
    private static let logger = Logger(subsystem: "Airlance", category: "Accounts")

    private(set) var lastSelected: AccountID?

    private let storage: any KeyValueStore
    private let keychain: Keychain
    private let observers = ObserverList<AccountEvent>()
    private var stored: [AccountRecord]
    private var removing: Set<AccountID> = []
    private var contexts: [AccountID: AccountContext] = [:]
    private var users: [AccountID: Set<UUID>] = [:]
    private var saving: Task<Void, Never>?

    init(storage: any KeyValueStore, keychain: Keychain) {
        self.storage = storage
        self.keychain = keychain
        stored = storage.value(for: .accounts)
        lastSelected = storage.value(for: .selectedAccount).map(AccountID.init(rawValue:))
        if !storage.value(for: .accountsMigrated) {
            migrateLegacyAccount()
        }
        for raw in storage.value(for: .removingAccounts) {
            let id = AccountID(rawValue: raw)
            removing.insert(id)
            finishRemoval(id)
        }
    }

    var records: [AccountRecord] {
        stored.filter { record in
            !removing.contains(record.id)
        }
    }

    func record(_ id: AccountID) -> AccountRecord? {
        records.first { record in
            record.id == id
        }
    }

    func isAvailable(_ id: AccountID) -> Bool {
        record(id) != nil
    }

    func initialAccount(preferred: AccountID?) -> AccountID? {
        if let preferred, isAvailable(preferred) {
            return preferred
        }

        if let lastSelected, isAvailable(lastSelected) {
            return lastSelected
        }

        return records.first?.id
    }

    func observe(_ onEvent: @escaping @MainActor @Sendable (AccountEvent) -> Void) -> ObservationToken {
        observers.add(onEvent)
    }

    func context(for id: AccountID) -> Result<AccountContext, AccountOpenFailure> {
        guard let record = record(id) else {
            return .failure(AccountOpenFailure(accountID: id, message: "unavailable account"))
        }

        if let context = contexts[id] {
            return .success(context)
        }

        do {
            let context = try AccountContext(record: record, keychain: keychain)
            contexts[id] = context

            return .success(context)
        } catch {
            Self.logger.error("Can't open account \(id.rawValue): \(error)")

            return .failure(AccountOpenFailure(accountID: id, message: String(describing: error)))
        }
    }

    func use(_ id: AccountID) -> ObservationToken {
        let token = UUID()
        users[id, default: []].insert(token)

        return ObservationToken { [weak self] in
            Task { @MainActor in
                self?.users[id]?.remove(token)
            }
        }
    }

    func isInUse(_ id: AccountID) -> Bool {
        !(users[id]?.isEmpty ?? true)
    }

    func select(_ id: AccountID) {
        guard lastSelected != id, isAvailable(id) else {
            return
        }

        lastSelected = id
        save(selected: id)
    }

    func unload(_ id: AccountID) async {
        guard !isInUse(id), let context = contexts.removeValue(forKey: id) else {
            return
        }

        await context.close()
    }

    func addDemoAccount() -> AccountRecord {
        let variant = (stored.map(\.fixtureVariant).max() ?? 0) + 1
        let record = AccountRecord(id: .make(), name: "", isDemo: true, fixtureVariant: variant, createdAt: Date())
        stored.append(record)
        save(records: stored)
        observers.notify(.changed)

        return record
    }

    func remove(_ id: AccountID) async {
        guard isAvailable(id) else {
            return
        }

        removing.insert(id)
        await enqueue(saveRemoving()).value
        observers.notify(.willRemove(id))
        users[id] = nil
        if let context = contexts.removeValue(forKey: id) {
            await context.close()
        }
        finishRemoval(id)
        observers.notify(.changed)
    }

    private func finishRemoval(_ id: AccountID) {
        do {
            try AccountContext.remove(accountID: id, keychain: keychain)
        } catch {
            Self.logger.error("Can't remove data of account \(id.rawValue), retrying next launch: \(error)")

            return
        }

        stored.removeAll { record in
            record.id == id
        }
        save(records: stored)
        if lastSelected == id {
            lastSelected = records.first?.id
            save(selected: lastSelected)
        }
        removing.remove(id)
        enqueue(saveRemoving())
    }

    private func migrateLegacyAccount() {
        if stored.isEmpty {
            stored = [
                AccountRecord(id: .legacyLocal, name: "", isDemo: true, fixtureVariant: 0, createdAt: Date()),
            ]
            lastSelected = .legacyLocal
            save(records: stored)
            save(selected: .legacyLocal)
        }
        enqueue { storage in
            try await storage.update(.accountsMigrated) { value in
                value = true
            }
        }
    }

    private func saveRemoving() -> @MainActor (any KeyValueStore) async throws -> Void {
        let ids = removing.map(\.rawValue).sorted()

        return { storage in
            try await storage.update(.removingAccounts) { value in
                value = ids
            }
        }
    }

    private func save(records: [AccountRecord]) {
        enqueue { storage in
            try await storage.update(.accounts) { value in
                value = records
            }
        }
    }

    private func save(selected: AccountID?) {
        let raw = selected?.rawValue
        enqueue { storage in
            try await storage.update(.selectedAccount) { value in
                value = raw
            }
        }
    }

    @discardableResult
    private func enqueue(_ write: @escaping @MainActor (any KeyValueStore) async throws -> Void) -> Task<Void, Never> {
        let previous = saving
        let task = Task { [storage] in
            await previous?.value
            do {
                try await write(storage)
            } catch {
                Self.logger.error("Can't save accounts: \(error)")
            }
        }
        saving = task

        return task
    }
}
