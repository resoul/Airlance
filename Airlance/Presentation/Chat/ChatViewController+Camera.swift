import CameraUI
import ChatHistory
import UIKit

extension ChatViewController {
    func prepareCameraTile(in sheet: AttachSheet) {
        guard dependencies.permissionFlow.isAuthorized(.takePhoto), let camera = camera() else {
            return
        }

        camera.start()
        sheet.gallery.cameraPreview = camera.preview
        sheet.onClosed = { [weak self] in
            guard let self, !self.isOpeningCamera else {
                return
            }

            self.chatCamera?.stop()
        }
    }

    func openCamera(from frame: CGRect?) {
        isOpeningCamera = true
        let flow = dependencies.permissionFlow
        Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.isOpeningCamera = false
            }
            guard await flow.authorize(.takePhoto, from: self), let camera = self.camera() else {
                return
            }

            self.presentCamera(camera, from: frame)
        }
    }

    private func camera() -> CameraSession? {
        if let chatCamera {
            return chatCamera
        }

        let store = dependencies.media
        chatCamera = CameraSession {
            store.reserve(.video, extension: "mov").url
        }

        return chatCamera
    }

    private func presentCamera(_ camera: CameraSession, from frame: CGRect?) {
        let controller = CameraViewController(
            session: camera,
            configuration: .app(
                strings: presentation.strings,
                permissions: dependencies.permissionFlow,
                videoNotes: dependencies.videoNotes,
                videoLimit: 60,
                modes: [.photo, .video, .square, .burst],
                gallery: CameraLibrary(permissions: dependencies.permissionFlow),
                selectionLimit: 10
            ),
            origin: frame
        )
        let cameraFlow = ChatCameraFlow(
            controller: controller,
            presentation: presentation,
            media: dependencies.media,
            permissions: dependencies.permissionFlow
        )
        controller.onOpenURL = { [weak self, weak controller] url in
            controller?.close()
            self?.router.open(.browser(url))
        }
        cameraFlow.onSend = { [weak self] items, caption in
            self?.sendCaptured(items, caption: caption)
        }
        cameraFlow.onClose = { [weak self] in
            self?.cameraFlow = nil
        }
        self.cameraFlow = cameraFlow
        inputBar.dismissKeyboard()
        present(controller, animated: false)
    }

    private func sendCaptured(_ items: [CameraItem], caption: String) {
        let store = dependencies.media
        Task { [weak self] in
            var photos: [MessagePhoto] = []
            for item in items {
                switch item {
                case .photo(let image):
                    if let photo = AttachExport.photo(from: image, store: store) {
                        photos.append(photo)
                    }
                case .video(let url, _):
                    if let photo = await AttachExport.video(at: url, store: store) {
                        photos.append(photo)
                    }
                }
            }
            self?.sendPhotos(photos, caption: caption)
        }
    }
}
