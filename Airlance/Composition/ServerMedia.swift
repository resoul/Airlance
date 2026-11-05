import ChatStorage
import Foundation
import ImageIO
import MediaStore
import Protocol
import UniformTypeIdentifiers

enum ServerThumbnail {
    private static let side = 320
    private static let quality = 0.7

    nonisolated static func make(from source: URL) -> URL? {
        guard let image = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(image, 0, options as CFDictionary) else {
            return nil
        }

        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        let type = UTType.jpeg.identifier as CFString
        guard let writer = CGImageDestinationCreateWithURL(target as CFURL, type, 1, nil) else {
            return nil
        }

        let settings = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(writer, thumbnail, settings)

        return CGImageDestinationFinalize(writer) ? target : nil
    }
}

@MainActor
final class ServerAttachmentUploader {
    private let files: ProfileMediaFiles
    private let storage: ChatStorage
    private let account: String

    init(files: ProfileMediaFiles, storage: ChatStorage, account: String) {
        self.files = files
        self.storage = storage
        self.account = account
    }

    func uploaded(_ message: StoredMessage) async throws -> StoredMessage {
        var next = message
        for index in next.attachments.indices where next.attachments[index].mediaID.isEmpty {
            try await upload(&next.attachments[index])
            try await storage.saveAttachments(of: next)
        }

        return next
    }

    private func upload(_ item: inout StoredAttachment) async throws {
        let media = item.localMedia(account: account)
        let url = MediaStore.url(for: media)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AccountMessagingError.missingFile
        }

        item.size = MediaStore.size(of: url)
        item.mediaID = try await files.upload(url)
        guard let thumb = item.thumbMedia(account: account), item.thumbMediaID.isEmpty else {
            return
        }

        let source = MediaStore.url(for: thumb)
        let small = await Task.detached {
            ServerThumbnail.make(from: source)
        }.value
        if let small {
            item.thumbMediaID = try await files.upload(small)
            try? FileManager.default.removeItem(at: small)
        }
    }
}

@MainActor
final class ServerMediaFetcher {
    private static let limit = 3

    private struct Job {
        let mediaID: String
        let media: LocalMedia
        let onReady: @MainActor () -> Void
    }

    private let files: ProfileMediaFiles
    private var queue: [Job] = []
    private var known: Set<String> = []
    private var running = 0

    init(files: ProfileMediaFiles) {
        self.files = files
    }

    func fetch(_ mediaID: String, to media: LocalMedia, onReady: @escaping @MainActor () -> Void) {
        guard !mediaID.isEmpty, !FileManager.default.fileExists(atPath: MediaStore.url(for: media).path) else {
            return
        }

        guard known.insert(mediaID).inserted else {
            return
        }

        queue.insert(Job(mediaID: mediaID, media: media, onReady: onReady), at: 0)
        startNext()
    }

    func fetchNow(_ mediaID: String, to media: LocalMedia) async {
        let target = MediaStore.url(for: media)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            return
        }

        await copy(mediaID, to: target)
    }

    private func startNext() {
        while running < Self.limit, !queue.isEmpty {
            let job = queue.removeFirst()
            running += 1
            Task { [weak self] in
                await self?.copy(job.mediaID, to: MediaStore.url(for: job.media))
                self?.finished(job)
            }
        }
    }

    private func finished(_ job: Job) {
        running -= 1
        known.remove(job.mediaID)
        if FileManager.default.fileExists(atPath: MediaStore.url(for: job.media).path) {
            job.onReady()
        }
        startNext()
    }

    private func copy(_ mediaID: String, to target: URL) async {
        let ext = target.pathExtension
        guard let source = await files.file(mediaID, extension: ext) else {
            return
        }

        let manager = FileManager.default
        try? manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.copyItem(at: source, to: target)
    }
}

extension ServerAttachment {
    init(stored item: StoredAttachment) {
        self.init(
            kind: Int32(item.kind.rawValue),
            mediaID: item.mediaID,
            thumbMediaID: item.thumbMediaID,
            name: item.name,
            size: item.size,
            width: Int32(item.width),
            height: Int32(item.height),
            durationMs: Int32(item.durationMs),
            waveform: item.waveform,
            title: item.title,
            performer: item.performer
        )
    }
}

extension StoredAttachment {
    init(server item: ServerAttachment) {
        self.init(
            kind: StoredAttachmentKind(rawValue: Int(item.kind)) ?? .file,
            mediaID: item.mediaID,
            thumbMediaID: item.thumbMediaID,
            name: item.name,
            size: item.size,
            width: Int(item.width),
            height: Int(item.height),
            durationMs: Int(item.durationMs),
            waveform: item.waveform,
            title: item.title,
            performer: item.performer
        )
    }
}
