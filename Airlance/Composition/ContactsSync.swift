import DatabaseAPI
import DeviceContacts
import Observers
import Permissions
import PermissionsAPI

extension StorageKey where Value == DeviceContactsSort {
    static let contactsSort = StorageKey("contacts.sort", default: .givenName)
}

@MainActor
final class ContactsSync {
    let store: DeviceContactsStore

    private let storage: any KeyValueStore
    private var contactsStatus: PermissionStatus?
    private var observations: [ObservationToken] = []

    init(storage: any KeyValueStore, permissionStore: PermissionStore) {
        self.storage = storage
        store = DeviceContactsStore(sort: storage.value(for: .contactsSort))

        observations = [
            storage.observe(.contactsSort) { [weak self] sort in
                self?.store.sort = sort
            },
            permissionStore.observe { [weak self] snapshot in
                self?.permissionChanged(snapshot.status(of: .contacts))
            },
        ]
    }

    func observeSort(_ onChange: @escaping @MainActor (DeviceContactsSort) -> Void) -> ObservationToken {
        storage.observe(.contactsSort, onChange: onChange)
    }

    func setSort(_ sort: DeviceContactsSort) async throws {
        try await storage.update(.contactsSort) { value in
            value = sort
        }
    }

    private func permissionChanged(_ status: PermissionStatus?) {
        guard status != contactsStatus else {
            return
        }

        contactsStatus = status
        store.reload()
    }
}
