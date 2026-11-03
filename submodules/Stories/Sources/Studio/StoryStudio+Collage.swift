import AVFoundation
import CameraUI
import Haptics
import UIKit

extension StoryStudio {
    func setUpCollage() {
        collageButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        collageButton.accessibilityLabel = context.strings.label(.collage)
        collageButton.addAction(UIAction { [weak self] _ in
            self?.toggleCollage()
        }, for: .touchUpInside)
        controller.setAccessory(collageButton)
    }

    func picked(_ captures: [CameraCapture]) {
        if collage != nil {
            fillCollage(with: captures, fromGallery: true)
        } else if captures.count > 1 {
            askMany(captures)
        } else if let first = captures.first {
            captured(first)
        }
    }

    func addToCollage(_ capture: CameraCapture) {
        fillCollage(with: [capture], fromGallery: false)
    }

    private func toggleCollage(layout: StoryCollageLayout = .grid4) {
        Haptics.play(.selection)
        guard collage == nil else {
            endCollage()

            return
        }

        let overlay = StoryCollageOverlay(layout: layout)
        overlay.onChange = { [weak self] in
            self?.collageChanged()
        }
        controller.setOverlay(overlay)
        collage = overlay
        collageButton.setImage(UIImage(systemName: "square.grid.2x2.fill"), for: .normal)
        collageButton.tintColor = .systemYellow
    }

    private func endCollage() {
        controller.setOverlay(nil)
        collage = nil
        collageButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        collageButton.tintColor = .white
    }

    private func fillCollage(with captures: [CameraCapture], fromGallery: Bool) {
        let preview = controller.previewSize
        Task { [weak self] in
            for capture in captures {
                guard let self, let overlay = self.collage, let cell = overlay.currentCell else {
                    return
                }

                guard let image = await Self.image(of: capture) else {
                    continue
                }

                overlay.fill(fromGallery ? image : StoryCollage.crop(image, to: cell, preview: preview))
            }
        }
    }

    private func collageChanged() {
        guard let overlay = collage, overlay.isFull else {
            return
        }

        Haptics.play(.success)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, let overlay = self.collage, overlay.isFull else {
                return
            }

            let bounds = self.controller.view.bounds.size
            let height = StoryExport.width * bounds.height / max(bounds.width, 1)
            let size = CGSize(width: StoryExport.width, height: height)
            let image = StoryCollage.render(overlay.layout, images: overlay.images.compactMap(\.self), size: size)
            self.endCollage()
            self.captured(.photo(image))
        }
    }

    private func askMany(_ captures: [CameraCapture]) {
        let strings = context.strings
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: strings.label(.collage), style: .default) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.toggleCollage(layout: .fitting(captures.count))
                self?.fillCollage(with: captures, fromGallery: true)
            }
        })
        let slides = strings.label(.collageSlides) + " (\(captures.count))"
        sheet.addAction(UIAlertAction(title: slides, style: .default) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publishSlides(captures)
            }
        })
        sheet.addAction(UIAlertAction(title: strings.cancel, style: .cancel))
        controller.present(sheet, animated: true)
    }

    static func image(of capture: CameraCapture) async -> UIImage? {
        switch capture {
        case .photo(let image):
            return image
        case .video(let url):
            let image = await poster(of: url)
            try? FileManager.default.removeItem(at: url)

            return image
        }
    }
}
