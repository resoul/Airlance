import Foundation

public final class MediaStore: Sendable {
    public let account: String

    public init(account: String) {
        self.account = account
    }

    public static var root: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media", isDirectory: true)
    }

    public static func removeLegacyFolders() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for name in ["Attachments", "Voice"] {
            try? FileManager.default.removeItem(at: caches.appendingPathComponent(name, isDirectory: true))
        }
    }

    public static func directory(for account: String) -> URL {
        root.appendingPathComponent(account, isDirectory: true)
    }

    public static func url(for media: LocalMedia) -> URL {
        directory(for: media.account)
            .appendingPathComponent(media.kind.rawValue, isDirectory: true)
            .appendingPathComponent(media.name)
    }

    public func reserve(_ kind: LocalMedia.Kind, extension ext: String) -> (media: LocalMedia, url: URL) {
        let media = LocalMedia(account: account, kind: kind, name: UUID().uuidString + "." + ext)
        let url = Self.url(for: media)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        return (media, url)
    }

    public func store(_ data: Data, kind: LocalMedia.Kind, extension ext: String) -> LocalMedia? {
        let target = reserve(kind, extension: ext)
        do {
            try data.write(to: target.url, options: .atomic)
        } catch {
            return nil
        }

        return target.media
    }

    public func copy(_ source: URL, kind: LocalMedia.Kind, keepingName: Bool) -> LocalMedia? {
        let ext = source.pathExtension
        let name = keepingName
            ? UUID().uuidString + "/" + source.lastPathComponent
            : UUID().uuidString + (ext.isEmpty ? "" : "." + ext)
        let media = LocalMedia(account: account, kind: kind, name: name)
        let target = Self.url(for: media)
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.copyItem(at: source, to: target)
        } catch {
            return nil
        }

        return media
    }

    public func adopt(_ url: URL, kind: LocalMedia.Kind) -> LocalMedia? {
        let directory = Self.directory(for: account).appendingPathComponent(kind.rawValue, isDirectory: true)
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            return copy(url, kind: kind, keepingName: false)
        }

        return LocalMedia(account: account, kind: kind, name: url.lastPathComponent)
    }

    public func remove(_ media: LocalMedia) {
        try? FileManager.default.removeItem(at: Self.url(for: media))
    }

    public static func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])

        return Int64(values?.fileSize ?? 0)
    }

    public func usage() -> Int64 {
        files().reduce(0) { total, file in
            total + file.size
        }
    }

    public func trim(to limit: Int64) {
        var files = files().sorted { lhs, rhs in
            lhs.date < rhs.date
        }
        var total = files.reduce(0) { total, file in
            total + file.size
        }
        while total > limit, !files.isEmpty {
            let file = files.removeFirst()
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: Self.directory(for: account))
    }

    private func files() -> [(url: URL, size: Int64, date: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: Self.directory(for: account),
            includingPropertiesForKeys: keys
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                return nil
            }

            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }
    }
}
