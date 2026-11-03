import DatabaseAPI
import Observers
import Routing

extension StorageKey where Value == [String] {
    static let navigationTabs = StorageKey("navigation.tabs", default: [])
}

@MainActor
final class TabSettings {
    static let all: [AppRoute] = [.contacts, .calls, .chats, .onAir, .settings]
    static let required: Set<AppRoute> = [.chats, .settings]

    private let storage: any KeyValueStore

    init(storage: any KeyValueStore) {
        self.storage = storage
    }

    var tabs: [AppRoute] {
        Self.sanitized(storage.value(for: .navigationTabs))
    }

    var hidden: [AppRoute] {
        let tabs = tabs

        return Self.all.filter { tab in
            !tabs.contains(tab)
        }
    }

    func setTabs(_ tabs: [AppRoute]) {
        let names = Self.sanitized(tabs.map(\.segment.name)).map(\.segment.name)
        let storage = storage
        Task {
            try? await storage.update(.navigationTabs) { value in
                value = names
            }
        }
    }

    func observe(_ onChange: @escaping @MainActor ([AppRoute]) -> Void) -> ObservationToken {
        storage.observe(.navigationTabs) { names in
            onChange(Self.sanitized(names))
        }
    }

    private static func sanitized(_ names: [String]) -> [AppRoute] {
        guard !names.isEmpty else {
            return all
        }

        var tabs: [AppRoute] = []
        for name in names {
            guard let tab = AppRoute(segment: RouteSegment(name)), all.contains(tab), !tabs.contains(tab) else {
                continue
            }

            tabs.append(tab)
        }
        for tab in all where required.contains(tab) && !tabs.contains(tab) {
            tabs.append(tab)
        }

        return tabs
    }
}
