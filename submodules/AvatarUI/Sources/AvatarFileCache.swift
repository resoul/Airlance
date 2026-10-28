import CryptoKit
import Foundation

actor AvatarFileCache {
    static let shared = AvatarFileCache()

    private static let diskLimit = 128 * 1024 * 1024

    private let directory: URL
    private var downloads: [String: Task<URL, any Error>] = [:]

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = caches.appendingPathComponent("AvatarUI", isDirectory: true)
    }

    func data(for url: URL, key: String) async -> Data? {
        guard let file = try? await fileURL(for: url, key: key) else {
            return nil
        }

        return try? Data(contentsOf: file, options: .mappedIfSafe)
    }

    func fileURL(for url: URL, key: String) async throws -> URL {
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw URLError(.fileDoesNotExist)
            }

            return url
        }

        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            throw URLError(.unsupportedURL)
        }

        let destination = directory
            .appendingPathComponent(Self.fileName(url: url, key: key))
            .appendingPathExtension(url.pathExtension)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        if let running = downloads[destination.path] {
            return try await running.value
        }

        let directory = directory
        let task = Task {
            try await Self.download(url, to: destination, directory: directory)
        }
        downloads[destination.path] = task
        defer {
            downloads[destination.path] = nil
        }

        let file = try await task.value
        trim(keeping: file)

        return file
    }

    private static func download(_ url: URL, to destination: URL, directory: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer {
            try? FileManager.default.removeItem(at: temporary)
        }

        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }

        return destination
    }

    private static func fileName(url: URL, key: String) -> String {
        let digest = SHA256.hash(data: Data("\(key)|\(url.absoluteString)".utf8))
        let bytes = digest.map { byte in
            String(format: "%02x", byte)
        }

        return bytes.joined()
    }

    private func trim(keeping current: URL) {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        ) else {
            return
        }

        var files = urls.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }

            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = files.reduce(0) { sum, file in
            sum + file.size
        }
        files.sort { lhs, rhs in
            lhs.date < rhs.date
        }
        for file in files where total > Self.diskLimit && file.url != current {
            if (try? FileManager.default.removeItem(at: file.url)) != nil {
                total -= file.size
            }
        }
    }
}
