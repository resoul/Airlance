import CameraUI
import MediaStore
import UIKit

@MainActor
final class AvatarCameraFlow {
    private static let videoLimit: TimeInterval = 60

    var onCaptured: (@MainActor (CameraCapture, CGSize?) -> Void)?

    private let media: MediaStore
    private let permissions: PermissionFlow
    private let videoNotes: VideoNoteSettings
    private var session: CameraSession?
    private var controller: CameraViewController?
    private var capture: CameraCapture?
    private var framing: CGSize?
    private var isOpening = false

    init(media: MediaStore, permissions: PermissionFlow, videoNotes: VideoNoteSettings) {
        self.media = media
        self.permissions = permissions
        self.videoNotes = videoNotes
    }

    func prepareTile(in sheet: AttachSheet) {
        guard permissions.isAuthorized(.takePhoto), let camera = camera() else {
            return
        }

        camera.start()
        sheet.gallery.cameraPreview = camera.preview
        sheet.onClosed = { [weak self] in
            guard let self, !self.isOpening else {
                return
            }

            self.session?.stop()
        }
    }

    func open(from frame: CGRect?, presenter: UIViewController, strings: AppStrings) {
        isOpening = true
        let permissions = permissions
        Task { [weak self, weak presenter] in
            guard let self, let presenter else {
                return
            }

            defer {
                self.isOpening = false
            }
            guard await permissions.authorize(.takePhoto, from: presenter), let camera = self.camera() else {
                return
            }

            self.present(camera, from: frame, presenter: presenter, strings: strings)
        }
    }

    private func camera() -> CameraSession? {
        if let session {
            return session
        }

        let media = media
        session = CameraSession {
            media.reserve(.video, extension: "mov").url
        }

        return session
    }

    private func present(
        _ camera: CameraSession,
        from frame: CGRect?,
        presenter: UIViewController,
        strings: AppStrings
    ) {
        let controller = CameraViewController(
            session: camera,
            configuration: .app(
                strings: strings,
                permissions: permissions,
                videoNotes: videoNotes,
                videoLimit: Self.videoLimit,
                modes: [.photo, .video]
            ),
            origin: frame
        )
        controller.onCapture = { [weak self, weak controller] capture in
            self?.capture = capture
            self?.framing = controller?.previewSize
            controller?.close(sending: true)
        }
        controller.onClose = { [weak self] in
            self?.closed()
        }
        self.controller = controller
        camera.start()
        presenter.present(controller, animated: false) { [weak controller] in
            let guide = AvatarCameraGuide()
            guide.alpha = 0
            controller?.setOverlay(guide)
            UIView.animate(withDuration: 0.25) {
                guide.alpha = 1
            }
        }
    }

    private func closed() {
        controller = nil
        let shot = capture
        capture = nil
        if let shot {
            onCaptured?(shot, framing)
        }
    }
}
