import ChatHistory
import MediaStore
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

extension ChatViewController {
    private static let albumLimit = 10

    func showAttachMenu() {
        guard canWrite, let host = view.window else {
            return
        }

        inputBar.dismissKeyboard()
        var tabs: [AttachSheet.Tab] = [.gallery, .location]
        if canCreatePolls {
            tabs.append(.poll)
        }
        tabs += [.sound, .contact, .file]
        let sheet = AttachSheet(
            tabs: tabs,
            presentation: presentation,
            contacts: dependencies.contacts,
            host: host
        )
        bindAttach(sheet)
        sheet.sound.setFiles(attachSoundFiles())
        prepareCameraTile(in: sheet)
        sheet.present()
    }

    private func bindAttach(_ sheet: AttachSheet) {
        let flow = dependencies.permissionFlow
        sheet.authorize = { [weak self] tab in
            guard let self else {
                return false
            }

            switch tab {
            case .location:
                return await flow.authorize(.sendLocation, from: self)
            case .contact:
                return await flow.authorize(.shareContact, from: self)
            default:
                return await flow.authorize(.attachMedia, from: self)
            }
        }
        sheet.isLimited = {
            PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
        }
        sheet.onManage = { [weak self] in
            if let self {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }
        }
        sheet.onSendMedia = { [weak self] assets, caption in
            self?.sendAssets(assets, caption: caption)
        }
        sheet.onCamera = { [weak self] frame in
            self?.openCamera(from: frame)
        }
        sheet.onFile = { [weak self] in
            self?.pickFiles(types: [.item])
        }
        bindAttachSound(sheet)
        sheet.onLocation = { [weak self] pick in
            self?.sendLocation(pick)
        }
        sheet.onPoll = { [weak self] in
            self?.composePoll()
        }
    }

    private func sendAssets(_ assets: [PHAsset], caption: String) {
        let store = dependencies.media
        Task { [weak self] in
            let photos = await AttachExport.photos(assets, store: store)
            self?.sendPhotos(photos, caption: caption)
        }
    }

    func sendPhotos(_ photos: [MessagePhoto], caption: String) {
        guard !photos.isEmpty else {
            return
        }

        let chunks = stride(from: 0, to: photos.count, by: Self.albumLimit).map { start in
            Array(photos[start..<min(start + Self.albumLimit, photos.count)])
        }
        for (index, chunk) in chunks.enumerated() {
            postAttachment(.photos(chunk, caption: index == 0 ? caption : ""))
        }
    }

    func postAttachment(_ content: MessageContent) {
        let reply = replyTarget.map { message in
            MessageReply(message, quote: replyQuote)
        }
        history.scrollsToBottom = true
        dependencies.historyStore.postContent(content, to: id, reply: reply)
        cancelReply()
    }

    private func sendLocation(_ pick: AttachLocationView.Pick) {
        let location = MessageLocation(latitude: pick.coordinate.latitude, longitude: pick.coordinate.longitude)
        postAttachment(.location(location))
    }
}

extension ChatViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            guard let media = dependencies.media.copy(url, kind: .file, keepingName: true) else {
                continue
            }

            let file = MessageFile(
                name: url.lastPathComponent,
                size: MediaStore.size(of: MediaStore.url(for: media)),
                source: .local(media),
                isDownloaded: true
            )
            postAttachment(.file(file, caption: ""))
        }
    }
}
