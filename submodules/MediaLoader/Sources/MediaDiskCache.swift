import CryptoKit
import Foundation
import ImageIO
import MediaStore
import UIKit
import UniformTypeIdentifiers

public final class MediaDiskCache: Sendable {
    public static let shared = MediaDiskCache()

    private static let sharedScope = "shared"

    private let root: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        root = caches.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    func image(for source: MediaSource, pixels: CGSize) -> UIImage? {
        let url = file(for: source, pixels: pixels)
        guard
            let data = try? Data(contentsOf: url),
            let decoded = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(decoded, 0, nil)
        else {
            return nil
        }

        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)

        return UIImage(cgImage: image)
    }

    func store(_ image: UIImage, for source: MediaSource, pixels: CGSize) {
        guard let cgImage = image.cgImage else {
            return
        }

        let url = file(for: source, pixels: pixels)
        let data = NSMutableData()
        let type = Self.isOpaque(cgImage) ? UTType.jpeg : UTType.png
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            return
        }

        let options = [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else {
            return
        }

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? (data as Data).write(to: url, options: .atomic)
    }

    public func usage() -> Int64 {
        entries().reduce(0) { total, entry in
            total + entry.size
        }
    }

    public func trim(to limit: Int64) {
        var entries = entries().sorted { lhs, rhs in
            lhs.date < rhs.date
        }
        var total = entries.reduce(0) { total, entry in
            total + entry.size
        }
        while total > limit, !entries.isEmpty {
            let entry = entries.removeFirst()
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    public func remove(account: String) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(account, isDirectory: true))
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }

    private func file(for source: MediaSource, pixels: CGSize) -> URL {
        let key = "\(source.cacheKey)|\(Int(pixels.width))x\(Int(pixels.height))"
        let bytes = SHA256.hash(data: Data(key.utf8)).map { byte in
            String(format: "%02x", byte)
        }
        let digest = bytes.joined()

        return root
            .appendingPathComponent(Self.scope(of: source), isDirectory: true)
            .appendingPathComponent(digest)
    }

    private static func scope(of source: MediaSource) -> String {
        if case .local(let media) = source {
            return media.account
        }

        return sharedScope
    }

    private static func isOpaque(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            true
        default:
            false
        }
    }

    private func entries() -> [(url: URL, size: Int64, date: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            return []
        }

        var entries: [(url: URL, size: Int64, date: Date)] = []
        for case let url as URL in enumerator {
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true
            else {
                continue
            }

            entries.append((url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast))
        }

        return entries
    }
}
