import DatabaseAPI
import Observers

enum VideoNoteStyle: String, Codable, Sendable, CaseIterable {
    case blob
    case dualCamera
    case anonymous
    case moment
}

extension StorageKey where Value == String {
    static let videoNoteStyle = StorageKey("videoNote.style", default: VideoNoteStyle.blob.rawValue)
}

extension StorageKey where Value == Bool {
    static let videoReactions = StorageKey("videoNote.reactions", default: true)
    static let cameraVolumeZoom = StorageKey("camera.volumeZoom", default: false)
    static let cameraAutoSubtitles = StorageKey("camera.autoSubtitles", default: false)
}

@MainActor
final class VideoNoteSettings {
    private let storage: any KeyValueStore

    init(storage: any KeyValueStore) {
        self.storage = storage
    }

    var style: VideoNoteStyle {
        VideoNoteStyle(rawValue: storage.value(for: .videoNoteStyle)) ?? .blob
    }

    var reactionsEnabled: Bool {
        storage.value(for: .videoReactions)
    }

    var volumeZoomEnabled: Bool {
        storage.value(for: .cameraVolumeZoom)
    }

    var autoSubtitlesEnabled: Bool {
        storage.value(for: .cameraAutoSubtitles)
    }

    func setStyle(_ style: VideoNoteStyle) {
        let storage = storage
        Task {
            try? await storage.update(.videoNoteStyle) { value in
                value = style.rawValue
            }
        }
    }

    func setReactionsEnabled(_ isEnabled: Bool) {
        set(.videoReactions, isEnabled)
    }

    func setVolumeZoomEnabled(_ isEnabled: Bool) {
        set(.cameraVolumeZoom, isEnabled)
    }

    func setAutoSubtitlesEnabled(_ isEnabled: Bool) {
        set(.cameraAutoSubtitles, isEnabled)
    }

    func observe(_ onChange: @escaping @MainActor () -> Void) -> [ObservationToken] {
        [
            storage.observe(.videoNoteStyle) { _ in
                onChange()
            },
            storage.observe(.videoReactions) { _ in
                onChange()
            },
            storage.observe(.cameraVolumeZoom) { _ in
                onChange()
            },
            storage.observe(.cameraAutoSubtitles) { _ in
                onChange()
            },
        ]
    }

    private func set(_ key: StorageKey<Bool>, _ isEnabled: Bool) {
        let storage = storage
        Task {
            try? await storage.update(key) { value in
                value = isEnabled
            }
        }
    }
}
