import Observers

@MainActor
final class CallsStore {
    private(set) var entries: [CallEntry]

    private let observers = ObserverList<[CallEntry]>()

    init(entries: [CallEntry]) {
        self.entries = entries
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([CallEntry]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(entries)

        return token
    }

    func delete(_ id: String) {
        entries.removeAll { entry in
            entry.id == id
        }
        observers.notify(entries)
    }

    func deleteAll() {
        guard !entries.isEmpty else {
            return
        }

        entries = []
        observers.notify(entries)
    }
}
