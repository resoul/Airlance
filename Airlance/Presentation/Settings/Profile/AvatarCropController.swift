import Haptics
import MediaStore
import MozjpegBinding
import UIKit

final class AvatarCropController: UIViewController, UIScrollViewDelegate {
    nonisolated private static let outputSide: CGFloat = 1024
    nonisolated private static let quality: Int32 = 80
    private static let maximumZoom: CGFloat = 5

    var onDone: (@MainActor (LocalMedia) -> Void)?

    private let image: UIImage
    private let framing: CGSize?
    private let store: MediaStore
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let holeView = AvatarHoleView()
    private let chrome: AvatarEditorChrome
    private var hole = CGRect.zero

    init(image: UIImage, framing: CGSize?, store: MediaStore, presentation: PresentationData) {
        self.image = image
        self.framing = framing
        self.store = store
        chrome = AvatarEditorChrome(hint: presentation.strings.avatarEditorMoveHint, presentation: presentation)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        scrollView.addSubview(imageView)
        scrollView.contentSize = image.size
        view.addSubview(scrollView)
        view.addSubview(holeView)
        view.addSubview(chrome)
        chrome.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        chrome.onDone = { [weak self] in
            self?.finish()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        let side = bounds.width - 16
        let next = CGRect(x: 8, y: (bounds.height - side) / 2, width: side, height: side)
        scrollView.frame = bounds
        holeView.frame = bounds
        holeView.hole = next
        chrome.frame = CGRect(
            x: 16,
            y: bounds.height - view.safeAreaInsets.bottom - 68,
            width: bounds.width - 32,
            height: 52
        )
        guard next != hole else {
            return
        }

        hole = next
        placeImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    private func placeImage() {
        let bounds = view.bounds
        scrollView.contentInset = UIEdgeInsets(
            top: hole.minY,
            left: hole.minX,
            bottom: bounds.height - hole.maxY,
            right: bounds.width - hole.maxX
        )
        let shortest = max(1, min(image.size.width, image.size.height))
        let fill = hole.width / shortest
        scrollView.minimumZoomScale = fill
        scrollView.maximumZoomScale = max(fill * Self.maximumZoom, 1)
        let zoom = fill / AvatarFraming.fraction(content: image.size, preview: framing)
        scrollView.maximumZoomScale = max(zoom * Self.maximumZoom, 1)
        scrollView.zoomScale = zoom
        let shown = CGSize(width: image.size.width * zoom, height: image.size.height * zoom)
        scrollView.contentOffset = CGPoint(
            x: (shown.width - hole.width) / 2 - hole.minX,
            y: (shown.height - hole.height) / 2 - hole.minY
        )
    }

    private func finish() {
        let zoom = max(scrollView.zoomScale, 0.0001)
        let crop = CGRect(
            x: (scrollView.contentOffset.x + hole.minX) / zoom,
            y: (scrollView.contentOffset.y + hole.minY) / zoom,
            width: hole.width / zoom,
            height: hole.height / zoom
        )
        let source = SendableImage(image: image)
        let store = store
        chrome.setBusy(true)
        Task { [weak self] in
            let stored = await Task.detached(priority: .userInitiated) {
                Self.render(source, crop: crop).flatMap { jpeg in
                    store.store(jpeg, kind: .image, extension: "jpg")
                }
            }.value
            guard let self else {
                return
            }

            self.chrome.setBusy(false)
            guard let stored else {
                Haptics.play(.warning)

                return
            }

            Haptics.play(.success)
            self.onDone?(stored)
            self.dismiss(animated: true)
        }
    }

    nonisolated private static func render(_ source: SendableImage, crop: CGRect) -> Data? {
        guard let image = source.image, crop.width > 0 else {
            return nil
        }

        let side = outputSide
        let scale = side / crop.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let square = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            UIColor.black.setFill()
            context.fill(bounds)
            image.draw(in: CGRect(
                x: -crop.minX * scale,
                y: -crop.minY * scale,
                width: image.size.width * scale,
                height: image.size.height * scale
            ))
        }
        guard let pixels = square.cgImage else {
            return nil
        }

        return MozjpegEncode(pixels, quality)
    }
}
