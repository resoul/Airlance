import DatabaseAPI
import Observers

extension StorageKey where Value == Bool {
    static let translationButton = StorageKey("translation.button", default: true)
    static let translationChats = StorageKey("translation.chats", default: false)
}

extension StorageKey where Value == String {
    static let translationSkipped = StorageKey("translation.skipped", default: "")
}

@MainActor
final class TranslationSettings {
    private let storage: any KeyValueStore

    init(storage: any KeyValueStore) {
        self.storage = storage
    }

    var showsButton: Bool {
        storage.value(for: .translationButton)
    }

    var translatesChats: Bool {
        storage.value(for: .translationChats)
    }

    var skipped: Set<String> {
        Set(storage.value(for: .translationSkipped).split(separator: ",").map(String.init))
    }

    func skips(_ language: String) -> Bool {
        skipped.contains(language)
    }

    func setShowsButton(_ isOn: Bool) {
        set(.translationButton, isOn)
    }

    func setTranslatesChats(_ isOn: Bool) {
        set(.translationChats, isOn)
    }

    func setSkipped(_ languages: Set<String>) {
        let storage = storage
        let value = languages.sorted().joined(separator: ",")
        Task {
            try? await storage.update(.translationSkipped) { stored in
                stored = value
            }
        }
    }

    func observe(_ onChange: @escaping @MainActor () -> Void) -> [ObservationToken] {
        [
            storage.observe(.translationButton) { _ in
                onChange()
            },
            storage.observe(.translationChats) { _ in
                onChange()
            },
            storage.observe(.translationSkipped) { _ in
                onChange()
            },
        ]
    }

    private func set(_ key: StorageKey<Bool>, _ isOn: Bool) {
        let storage = storage
        Task {
            try? await storage.update(key) { value in
                value = isOn
            }
        }
    }
}
