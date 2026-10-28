import Contacts
import Foundation
import Observers
import os

@MainActor
public final class DeviceContactsStore: NSObject {
    private static let logger = Logger(subsystem: "DeviceContacts", category: "Store")

    public private(set) var contacts: [DeviceContact] = []
    public private(set) var isLoaded = false
    public private(set) var revision = 0
    public let thumbnails = DeviceContactThumbnails()

    public var sort: DeviceContactsSort {
        didSet {
            if sort != oldValue {
                reload()
            }
        }
    }

    private let observers = ObserverList<[DeviceContact]>()
    private var generation = 0

    public init(sort: DeviceContactsSort) {
        self.sort = sort
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contactStoreChanged),
            name: .CNContactStoreDidChange,
            object: nil
        )
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable ([DeviceContact]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(contacts)

        return token
    }

    public func reload() {
        generation += 1
        let generation = generation
        let sort = sort

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try DeviceContactsReader.read(sort: sort)
                }
            }.value
            guard generation == self.generation else {
                return
            }

            switch result {
            case .success(let contacts):
                apply(contacts)
            case .failure(let error):
                Self.logger.error("Can't read contacts: \(error)")
                apply([])
            }
        }
    }

    public func add(_ draft: DeviceContactDraft) async throws {
        try await Task.detached(priority: .userInitiated) {
            try DeviceContactsWriter.add(draft)
        }.value
        reload()
    }

    private func apply(_ contacts: [DeviceContact]) {
        let changed = contacts != self.contacts || !isLoaded
        isLoaded = true
        self.contacts = contacts
        if changed {
            revision += 1
            observers.notify(contacts)
        }
    }

    @objc
    nonisolated private func contactStoreChanged() {
        thumbnails.removeAll()
        Task { @MainActor in
            self.reload()
        }
    }
}
