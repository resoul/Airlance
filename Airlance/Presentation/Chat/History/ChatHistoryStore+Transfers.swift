import ChatHistory
import Foundation
import MediaStore

extension HistoryMessage {
    var pendingDownload: Int64? {
        switch content {
        case .photos(let photos, _):
            let pending = photos.filter { photo in
                !photo.isDownloaded
            }

            return pending.isEmpty ? nil : pending.reduce(0) { total, photo in
                total + photo.size
            }
        case .file(let file, _):
            return file.isDownloaded ? nil : file.size
        default:
            return nil
        }
    }

    var uploadSize: Int64 {
        guard isOutgoing, forward == nil else {
            return 0
        }

        switch content {
        case .photos(let photos, _):
            return photos.reduce(0) { total, photo in
                total + (photo.size > 0 ? photo.size : Self.fileSize(photo.source))
            }
        case .file(let file, _):
            return file.size > 0 ? file.size : Self.fileSize(file.source)
        default:
            return 0
        }
    }

    private static func fileSize(_ source: MediaSource) -> Int64 {
        guard let url = source.url, let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else {
            return 0
        }

        return Int64(values.fileSize ?? 0)
    }
}

extension ChatHistoryStore {
    func upload(_ message: HistoryMessage, in id: String, onFinish: @escaping @MainActor () -> Void) -> Bool {
        let size = message.uploadSize
        guard size > 0 else {
            return false
        }

        transfers.start(TransferKey(chatID: id, messageID: message.id), direction: .upload, total: size) {
            onFinish()
        }

        return true
    }

    func download(_ messageID: String, in id: String) {
        guard let message = message(messageID, in: id), let size = message.pendingDownload else {
            return
        }

        if downloadServerMedia(messageID, in: id) {
            return
        }

        let key = TransferKey(chatID: id, messageID: messageID)
        transfers.start(key, direction: .download, total: size) { [weak self] in
            self?.markDownloaded(messageID, in: id)
        }
    }

    func cancelTransfer(_ messageID: String, in id: String) {
        let key = TransferKey(chatID: id, messageID: messageID)
        guard let progress = transfers.progress(key) else {
            return
        }

        transfers.cancel(key)
        if progress.direction == .upload {
            delete(messageID, from: id)
        }
    }

    func message(_ messageID: String, in id: String) -> HistoryMessage? {
        histories[id]?.messages.first { message in
            message.id == messageID
        }
    }

    func markDownloaded(_ messageID: String, in id: String) {
        update(messageID, in: id) { message in
            switch message.content {
            case .photos(var photos, let caption):
                for index in photos.indices {
                    photos[index].isDownloaded = true
                }
                message.content = .photos(photos, caption: caption)
            case .file(var file, let caption):
                file.isDownloaded = true
                message.content = .file(file, caption: caption)
            default:
                break
            }
        }
    }
}
