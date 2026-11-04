import AirlanceUI
import Haptics
import MediaStore
import PhotosUI
import UIKit
import UniformTypeIdentifiers

extension ProfileEditController {
    func birthdayRows() -> [SettingsOptionItem] {
        let strings = presentation.strings

        return [
            SettingsOptionItem(
                id: "birthday",
                title: strings.profileEditBirthday,
                detail: birthdayText ?? strings.profileEditSet,
                symbol: "birthday.cake.fill",
                iconColor: .systemBlue,
                accessory: .chevron,
                onSelect: { [weak self] in
                    self?.showBirthdayPicker()
                }
            ),
            SettingsOptionItem(
                id: "birthday-visibility",
                title: strings.profileEditVisibility,
                detail: title(of: draft.birthdayVisibility),
                symbol: "eye.fill",
                iconColor: .systemTeal,
                accessory: .chevron,
                onSelect: { [weak self] in
                    self?.showVisibilityMenu()
                }
            ),
        ]
    }

    var visibilityHint: String {
        presentation.strings.profileEditVisibilityHint(title(of: draft.birthdayVisibility))
    }

    func photoTapped() {
        guard let host = view.window else {
            return
        }

        let strings = presentation.strings
        var items = [
            PopupMenuItem(title: strings.profileEditChoosePhoto, symbol: "photo") { [weak self] in
                self?.showPhotoPicker()
            },
        ]
        if draft.photo != nil {
            let title = strings.profileEditRemovePhoto
            items.append(
                PopupMenuItem(title: title, symbol: "trash", isDestructive: true) { [weak self] in
                    self?.setPhoto(nil)
                }
            )
        }
        let anchor = CGRect(x: view.bounds.midX, y: view.safeAreaInsets.top + 120, width: 1, height: 40)
        PopupMenu.show(items, theme: presentation.theme, from: view.convert(anchor, to: host), in: host)
    }

    private var birthdayText: String? {
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

    private func showVisibilityMenu() {
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

    private func showBirthdayPicker() {
        view.endEditing(true)
        let content = BirthdaySheetController(birthday: draft.birthday, presentation: presentation)
        content.onPick = { [weak self] birthday in
            self?.draft.birthday = birthday
            self?.render()
        }
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            BirthdaySheetController.height
        }
        present(sheet, animated: false)
    }

    private func showPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func setPhoto(_ photo: LocalMedia?) {
        if let old = draft.photo, old != photo, old != dependencies.store.profile.photo {
            dependencies.store.media.remove(old)
        }
        draft.photo = photo
        render()
    }

    fileprivate func photoLoaded(_ data: Data) {
        let media = dependencies.store.media
        Task { [weak self] in
            let stored = await Task.detached(priority: .userInitiated) {
                Self.squareJPEG(data).flatMap { jpeg in
                    media.store(jpeg, kind: .image, extension: "jpg")
                }
            }.value
            if let stored {
                Haptics.play(.success)
                self?.setPhoto(stored)
            }
        }
    }

    nonisolated private static func squareJPEG(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let side: CGFloat = 1024
        let scale = side / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let square = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            image.draw(in: CGRect(
                x: (side - size.width) / 2,
                y: (side - size.height) / 2,
                width: size.width,
                height: size.height
            ))
        }

        return square.jpegData(compressionQuality: 0.85)
    }
}

extension ProfileEditController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            guard let data else {
                return
            }

            Task { @MainActor [weak self] in
                self?.photoLoaded(data)
            }
        }
    }
}
