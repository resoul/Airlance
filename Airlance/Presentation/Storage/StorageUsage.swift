import Foundation
import MediaLoader
import MediaStore
import ParticlesUI
import UIKit

enum StorageCategory: Int, CaseIterable, Sendable {
    case videos
    case photos
    case files
    case voice
    case thumbnails

    var color: UIColor {
        switch self {
        case .videos:
            .systemBlue
        case .photos:
            .systemTeal
        case .files:
            .systemOrange
        case .voice:
            .systemPurple
        case .thumbnails:
            .systemPink
        }
    }

    var symbol: String {
        switch self {
        case .videos:
            "video.fill"
        case .photos:
            "photo.fill"
        case .files:
            "doc.fill"
        case .voice:
            "waveform"
        case .thumbnails:
            "square.grid.2x2.fill"
        }
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .videos:
            strings.storageVideos
        case .photos:
            strings.storagePhotos
        case .files:
            strings.storageFiles
        case .voice:
            strings.storageVoice
        case .thumbnails:
            strings.storageThumbnails
        }
    }
}

struct StorageUsage: Sendable, Equatable {
    var bytes: [StorageCategory: Int64] = [:]

    var total: Int64 {
        bytes.values.reduce(0, +)
    }

    func size(_ category: StorageCategory) -> Int64 {
        bytes[category] ?? 0
    }
}

enum StorageEffect: Int, CaseIterable {
    case blackHole
    case dust
    case rows

    var symbol: String {
        switch self {
        case .blackHole:
            "hurricane"
        case .dust:
            "wind"
        case .rows:
            "list.bullet"
        }
    }

    var release: ParticleRelease {
        switch self {
        case .blackHole:
            .blackHole
        case .dust:
            .dust
        case .rows:
            .home
        }
    }

    var duration: TimeInterval {
        switch self {
        case .blackHole:
            1.6
        case .dust:
            1.8
        case .rows:
            2.0
        }
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .blackHole:
            strings.storageEffectBlackHole
        case .dust:
            strings.storageEffectDust
        case .rows:
            strings.storageEffectRows
        }
    }
}

struct StorageScanner: Sendable {
    let media: MediaStore

    static var previewFiles: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Files", isDirectory: true)
    }

    func scan() async -> StorageUsage {
        let media = media
        let task = Task.detached(priority: .userInitiated) {
            StorageUsage(bytes: [
                .videos: media.usage(of: .video),
                .photos: media.usage(of: .image),
                .files: media.usage(of: .file) + Self.size(of: Self.previewFiles),
                .voice: media.usage(of: .voice),
                .thumbnails: MediaDiskCache.shared.usage(),
            ])
        }

        return await task.value
    }

    func clear(_ categories: Set<StorageCategory>) async {
        let media = media
        await Task.detached(priority: .userInitiated) {
            for category in categories {
                switch category {
                case .videos:
                    media.remove(kind: .video)
                case .photos:
                    media.remove(kind: .image)
                case .files:
                    media.remove(kind: .file)
                    try? FileManager.default.removeItem(at: Self.previewFiles)
                case .voice:
                    media.remove(kind: .voice)
                case .thumbnails:
                    MediaDiskCache.shared.removeAll()
                }
            }
        }.value
        await MediaImageLoader.shared.removeAll()
    }

    private static func size(of directory: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }

            total += Int64(values.fileSize ?? 0)
        }

        return total
    }
}
