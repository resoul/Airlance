import DatabaseAPI
import Observers
import Routing

extension StorageKey where Value == String? {
    static let navigationTab = StorageKey("navigation.tab", default: nil)

    static func navigationTab(scene: String) -> StorageKey<String?> {
        StorageKey("navigation.tab.\(scene)", default: nil)
    }
}

@MainActor
final class TabMemory {
    private let storage: any KeyValueStore
    private let sceneKey: StorageKey<String?>
    private var savedTab: AppRoute?
    private var routerObservation: ObservationToken?

    var tab: AppRoute {
        savedTab ?? .chats
    }

    init(storage: any KeyValueStore, scene: String, legacy: (any KeyValueStore)?) {
        self.storage = storage
        sceneKey = .navigationTab(scene: scene)
        let saved = storage.value(for: sceneKey) ?? storage.value(for: .navigationTab)
        savedTab = (saved ?? legacy?.value(for: .navigationTab))
            .flatMap { name in
                AppRoute(segment: RouteSegment(name))
            }
            .flatMap { route in
                AppRoute.tabs.contains(route) ? route : nil
            }
    }

    func track(_ router: AppRouter) {
        routerObservation = router.observe { [weak self, weak router] _ in
            guard let tab = router?.tab else {
                return
            }

            self?.save(tab)
        }
    }

    private func save(_ tab: AppRoute) {
        guard tab != savedTab else {
            return
        }

        savedTab = tab
        let name = tab.segment.name
        let sceneKey = sceneKey
        Task { [storage] in
            _ = try? await storage.update(sceneKey) { value in
                value = name
            }
            _ = try? await storage.update(.navigationTab) { value in
                value = name
            }
        }
    }
}
