import CameraUI
import Haptics
import MediaStore
import Subtitles
import UIKit

@MainActor
final class ChatCameraFlow {
    var onSend: (@MainActor ([CameraItem], String) -> Void)?
    var onClose: (@MainActor () -> Void)?

    let controller: CameraViewController

    let presentation: PresentationData
    let media: MediaStore
    let permissions: PermissionFlow
    let recognizer = SubtitleRecognizer()
    var items: [CameraItem] = []
    var reviewIndex = 0
    var review: CameraReviewView?
    var subtitles: [URL: Subtitles] = [:]
    var language: String
    var editor: PhotoEditorView?
    weak var subtitleList: SubtitleListController?
    var subtitleTask: Task<Void, Never>?

    init(
        controller: CameraViewController,
        presentation: PresentationData,
        media: MediaStore,
        permissions: PermissionFlow
    ) {
        self.controller = controller
        self.presentation = presentation
        self.media = media
        self.permissions = permissions
        language = SubtitleRecognizer.language(for: presentation.strings.pack.locale)
        controller.onCapture = { [weak self] capture in
            self?.captured(capture)
        }
        controller.onPick = { [weak self] captures in
            self?.picked(captures)
        }
        controller.onThumbnail = { [weak self] in
            self?.showReview()
        }
        controller.onClose = { [weak self] in
            self?.onClose?()
        }
    }

    private func captured(_ capture: CameraCapture) {
        switch capture {
        case .photo(let image):
            add(.photo(image))
        case .video(let url):
            Task { [weak self] in
                let item = await CameraItem.video(at: url)
                self?.add(item)
            }
        }
    }

    private func add(_ item: CameraItem) {
        items.append(item)
        updateThumbnail()
        showReview(at: items.count - 1)
    }

    private func picked(_ captures: [CameraCapture]) {
        Task { [weak self] in
            var picked: [CameraItem] = []
            for capture in captures {
                switch capture {
                case .photo(let image):
                    picked.append(.photo(image))
                case .video(let url):
                    picked.append(await CameraItem.video(at: url))
                }
            }
            self?.append(picked)
        }
    }

    private func append(_ picked: [CameraItem]) {
        guard !picked.isEmpty else {
            return
        }

        let first = items.count
        items += picked
        updateThumbnail()
        showReview(at: first)
    }

    func showReview(at index: Int? = nil) {
        guard !items.isEmpty else {
            return
        }

        let index = min(index ?? items.count - 1, items.count - 1)
        let review = review ?? makeReview()
        review.show(items, index: index, subtitles: subtitles(for: items[index]))
        reviewIndex = index
        controller.isCaptureEnabled = false
        guard review.superview == nil else {
            return
        }

        review.frame = controller.view.bounds
        review.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        review.alpha = 0
        controller.view.addSubview(review)
        UIView.animate(withDuration: 0.25) {
            review.alpha = 1
        }
    }

    private func makeReview() -> CameraReviewView {
        let review = CameraReviewView(presentation: presentation)
        review.onRetake = { [weak self] in
            self?.retake()
        }
        review.onMore = { [weak self] in
            self?.hideReview()
        }
        review.onSelect = { [weak self] index in
            self?.showReview(at: index)
        }
        review.onSend = { [weak self] caption in
            self?.send(caption)
        }
        review.onTool = { [weak self] in
            self?.toolTapped()
        }
        self.review = review

        return review
    }

    private func retake() {
        Haptics.play(.tap)
        if items.indices.contains(reviewIndex) {
            items.remove(at: reviewIndex)
        }
        updateThumbnail()
        if items.isEmpty {
            hideReview()
        } else {
            showReview(at: max(0, reviewIndex - 1))
        }
    }

    private func hideReview() {
        guard let review else {
            return
        }

        review.stopVideo()
        review.endEditing(true)
        self.review = nil
        controller.isCaptureEnabled = true
        UIView.animate(withDuration: 0.2) {
            review.alpha = 0
        } completion: { _ in
            review.removeFromSuperview()
        }
    }

    private func send(_ caption: String) {
        review?.setSending(true)
        subtitleTask?.cancel()
        Task { [weak self] in
            guard let self else {
                return
            }

            let prepared = await self.burnSubtitles()
            Haptics.play(.success)
            self.onSend?(prepared, caption)
            self.controller.close(sending: true)
        }
    }

    private func updateThumbnail() {
        controller.setThumbnail(items.last?.preview, label: "\(items.count)")
    }
}
