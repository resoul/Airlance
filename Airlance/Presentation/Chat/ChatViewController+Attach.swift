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
        var tabs: [AttachSheet.Tab] = [.gallery, .file, .location]
        if canCreatePolls {
            tabs.append(.poll)
        }
        let sheet = AttachSheet(tabs: tabs, presentation: presentation, host: host)
        bindAttach(sheet)
        sheet.present()
    }

    private func bindAttach(_ sheet: AttachSheet) {
        let flow = dependencies.permissionFlow
        sheet.authorize = { [weak self] tab in
            guard let self else {
                return false
            }

            return await flow.authorize(tab == .location ? .sendLocation : .attachMedia, from: self)
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
        sheet.onCamera = { [weak self] in
            self?.openCamera()
        }
        sheet.onFile = { [weak self] in
            self?.pickFiles()
        }
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

    private func pickFiles() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }

        let flow = dependencies.permissionFlow
        Task { [weak self] in
            guard let self, await flow.authorize(.takePhoto, from: self) else {
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
            picker.delegate = self
            self.present(picker, animated: true)
        }
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

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        let movie = info[.mediaURL] as? URL
        picker.dismiss(animated: true)
        let store = dependencies.media
        Task { [weak self] in
            var photo: MessagePhoto?
            if let movie {
                photo = await AttachExport.video(at: movie, store: store)
            } else if let image {
                photo = AttachExport.photo(from: image, store: store)
            }
            if let photo {
                self?.sendPhotos([photo], caption: "")
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
