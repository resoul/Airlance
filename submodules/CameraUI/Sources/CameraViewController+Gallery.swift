import Haptics
import UIKit

extension CameraViewController {
    func setUpGallery() {
        guard let gallery = configuration.gallery else {
            galleryButton.isHidden = true

            return
        }

        galleryButton.clipsToBounds = true
        galleryButton.layer.cornerRadius = 10
        galleryButton.layer.borderWidth = 2
        galleryButton.layer.borderColor = UIColor.white.cgColor
        galleryButton.imageView?.contentMode = .scaleAspectFill
        galleryButton.tintColor = .white
        galleryButton.accessibilityLabel = configuration.strings.gallery
        galleryButton.addAction(UIAction { [weak self] _ in
            self?.openGallery()
        }, for: .touchUpInside)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp))
        swipe.direction = .up
        previewHost.addGestureRecognizer(swipe)
        gallery.onChange = { [weak self] in
            self?.refreshGalleryButton()
            self?.galleryPanel?.reload()
        }
        refreshGalleryButton()
    }

    func refreshGalleryButton() {
        guard let gallery = configuration.gallery else {
            return
        }

        guard gallery.isAuthorized, gallery.count >= 1 else {
            let symbol = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            galleryButton.setImage(UIImage(systemName: "photo.on.rectangle", withConfiguration: symbol), for: .normal)
            galleryButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)

            return
        }

        gallery.thumbnail(at: 0, side: 144) { [weak self] image in
            self?.galleryButton.setImage(image, for: .normal)
            self?.galleryButton.backgroundColor = .clear
        }
    }

    func openGallery() {
        guard let gallery = configuration.gallery, galleryPanel == nil, canChangeMode, isCaptureEnabled else {
            return
        }

        guard gallery.isAuthorized else {
            Task { [weak self] in
                guard let self, await gallery.authorize(from: self), gallery.isAuthorized else {
                    return
                }

                self.refreshGalleryButton()
                self.openGallery()
            }

            return
        }

        Haptics.play(.tap)
        let panel = CameraGalleryView(
            gallery: gallery,
            strings: configuration.strings,
            limit: configuration.selectionLimit
        )
        panel.frame = view.bounds
        panel.onClose = { [weak self] in
            self?.closeGallery()
        }
        panel.onPick = { [weak self] indices in
            self?.pick(indices)
        }
        view.addSubview(panel)
        galleryPanel = panel
        panel.layoutIfNeeded()
        panel.show()
    }

    func closeGallery() {
        guard let panel = galleryPanel else {
            return
        }

        galleryPanel = nil
        panel.hide {
            panel.removeFromSuperview()
        }
    }

    private func pick(_ indices: [Int]) {
        guard let gallery = configuration.gallery, let panel = galleryPanel, !indices.isEmpty else {
            return
        }

        panel.setLoading(true)
        Task { [weak self] in
            var captures: [CameraCapture] = []
            for index in indices {
                if let capture = await gallery.load(at: index) {
                    captures.append(capture)
                }
            }
            panel.setLoading(false)
            self?.closeGallery()
            guard !captures.isEmpty else {
                Haptics.play(.error)

                return
            }

            self?.onPick?(captures)
        }
    }

    @objc
    private func swipedUp() {
        openGallery()
    }
}
