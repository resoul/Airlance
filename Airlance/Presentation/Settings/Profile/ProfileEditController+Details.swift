import AirlanceUI
import CameraUI
import Haptics
import MediaStore
import Photos
import UIKit

extension ProfileEditController {
    static var defaultBirthday: ProfileBirthday {
        let date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)

        return ProfileBirthday(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    var visibilityHint: String {
        let strings = presentation.strings
        switch draft.birthdayVisibility {
        case .everyone:
            return strings.profileEditVisibilityHintEveryone
        case .contacts:
            return strings.profileEditVisibilityHintContacts
        case .nobody:
            return strings.profileEditVisibilityHintNobody
        }
    }

    func photoTapped() {
        guard let host = view.window else {
            return
        }

        view.endEditing(true)
        let strings = presentation.strings
        let sheet = AttachSheet(
            tabs: [.gallery],
            presentation: presentation,
            contacts: dependencies.contacts,
            host: host
        )
        let flow = dependencies.permissionFlow
        sheet.galleryTitle = strings.profileEditChangePhoto
        sheet.authorize = { [weak self] _ in
            guard let self else {
                return false
            }

            return await flow.authorize(.attachMedia, from: self)
        }
        sheet.isLimited = {
            PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
        }
        sheet.onManage = { [weak self] in
            if let self {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }
        }
        sheet.gallery.onPick = { [weak self, weak sheet] asset in
            sheet?.close {
                self?.assetPicked(asset)
            }
        }
        bindCamera(sheet)
        sheet.present()
    }

    var birthdayText: String? {
        draft.birthday.flatMap { birthday in
            let parts = DateComponents(year: birthday.year, month: birthday.month, day: birthday.day)
            let formatter = DateFormatter()
            formatter.locale = presentation.strings.pack.locale
            formatter.dateStyle = .medium

            return Calendar.current.date(from: parts).map(formatter.string(from:))
        }
    }

    private func title(of visibility: BirthdayVisibility) -> String {
        let strings = presentation.strings
        switch visibility {
        case .everyone:
            return strings.profileEditVisibilityEveryone
        case .contacts:
            return strings.profileEditVisibilityContacts
        case .nobody:
            return strings.profileEditVisibilityNobody
        }
    }

    func showVisibilityMenu() {
        guard let host = view.window else {
            return
        }

        view.endEditing(true)
        let items = BirthdayVisibility.allCases.map { visibility in
            PopupMenuItem(title: title(of: visibility), symbol: "eye") { [weak self] in
                self?.draft.birthdayVisibility = visibility
                self?.render()
            }
        }
        let anchor = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        PopupMenu.show(items, theme: presentation.theme, from: view.convert(anchor, to: host), in: host)
    }

    func applyNavigationBar(background: UIColor) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = nil
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }

    var avatarItem: ViewHostItem {
        ViewHostItem(
            id: "avatar",
            height: ProfileEditAvatarView.height,
            content: avatarView,
            inset: 0,
            revision: draft.photos.first?.photo?.name.hashValue ?? draft.photos.first?.photoMediaID?.hashValue ?? 0
        )
    }

    func showPhotoViewer() {
        guard !dependencies.store.profile.photos.isEmpty else {
            photoTapped()

            return
        }

        let viewer = ProfilePhotoViewerController(store: dependencies.store, index: 0, presentation: presentation)
        viewer.onChoose = { [weak self] in
            self?.photoTapped()
        }
        present(viewer, animated: true)
    }

    private func bindCamera(_ sheet: AttachSheet) {
        camera.prepareTile(in: sheet)
        camera.onCaptured = { [weak self] capture, framing in
            self?.captured(capture, framing: framing)
        }
        sheet.onCamera = { [weak self] frame in
            guard let self else {
                return
            }

            self.camera.open(from: frame, presenter: self, strings: self.presentation.strings)
        }
    }

    private func captured(_ capture: CameraCapture, framing: CGSize?) {
        switch capture {
        case .photo(let image):
            showPhotoEditor(image, framing: framing)
        case .video(let url):
            showVideoEditor(url, removesSource: true, framing: framing)
        }
    }

    private func assetPicked(_ asset: PHAsset) {
        Task { [weak self] in
            if asset.mediaType == .video {
                await self?.openVideoEditor(asset)
            } else {
                await self?.openPhotoEditor(asset)
            }
        }
    }

    private func openPhotoEditor(_ asset: PHAsset) async {
        guard let image = await AvatarAssets.image(asset) else {
            Haptics.play(.warning)

            return
        }

        showPhotoEditor(image, framing: nil)
    }

    private func showPhotoEditor(_ image: UIImage, framing: CGSize?) {
        let editor = AvatarCropController(
            image: image,
            framing: framing,
            store: dependencies.store.media,
            presentation: presentation
        )
        editor.onDone = { [weak self] stored in
            self?.dependencies.store.addPhoto(photo: stored, video: nil)
        }
        present(editor, animated: true)
    }

    private func openVideoEditor(_ asset: PHAsset) async {
        guard let source = await AvatarAssets.videoURL(asset) else {
            Haptics.play(.warning)

            return
        }

        showVideoEditor(source, removesSource: false, framing: nil)
    }

    private func showVideoEditor(_ source: URL, removesSource: Bool, framing: CGSize?) {
        let editor = AvatarVideoEditorController(
            source: source,
            removesSource: removesSource,
            framing: framing,
            store: dependencies.store.media,
            presentation: presentation
        )
        editor.onDone = { [weak self] processed in
            self?.dependencies.store.addPhoto(photo: processed.poster, video: processed.video)
        }
        present(editor, animated: true)
    }
}
