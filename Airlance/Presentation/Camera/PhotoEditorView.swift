import AirlanceUI
import Haptics
import Stories
import UIKit

final class PhotoEditorView: UIView {
    enum Mode {
        case idle
        case draw
        case crop
    }

    static let ratios: [CGFloat?] = [nil, 1, 3 / 4, 9 / 16]

    var onCancel: (@MainActor () -> Void)?
    var onDone: (@MainActor (UIImage) -> Void)?

    let strings: AppStrings
    let imageView = UIImageView()
    let palette = StoryPalette()
    let cropView = PhotoCropView()
    let ratioControl = LiquidSegmentedControl()
    let closeButton = UIButton(type: .system)
    let cropButton = UIButton(type: .system)
    let textButton = UIButton(type: .system)
    let drawButton = UIButton(type: .system)
    let undoButton = UIButton(type: .system)
    let doneButton = UIButton(type: .system)
    let rotateButton = UIButton(type: .system)
    let applyButton = UIButton(type: .system)
    var canvas = StoryCanvasView()
    var image: UIImage
    var mode = Mode.idle
    var ratioIndex = 0
    var textEditor: StoryTextEditor?

    init(image: UIImage, strings: AppStrings) {
        self.image = image
        self.strings = strings
        super.init(frame: .zero)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        addSubview(imageView)
        installCanvas()
        cropView.isHidden = true
        addSubview(cropView)
        palette.onSelect = { [weak self] color in
            self?.canvas.color = color
        }
        setUpTools()
        apply(.idle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var imageRect: CGRect {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return bounds
        }

        let area = bounds.inset(by: UIEdgeInsets(
            top: max(safeAreaInsets.top, 16) + 60,
            left: 12,
            bottom: max(safeAreaInsets.bottom, 16) + 76,
            right: 12
        ))
        let scale = min(area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)

        return CGRect(
            x: area.midX - fitted.width / 2,
            y: area.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = imageRect
        imageView.frame = rect
        canvas.frame = rect
        if cropView.frame != rect {
            cropView.frame = rect
            cropView.reset(ratio: Self.ratios[ratioIndex])
        }
        textEditor?.frame = bounds
        layoutTools()
    }

    func installCanvas() {
        canvas.removeFromSuperview()
        let canvas = StoryCanvasView()
        canvas.color = palette.selected
        canvas.onEditText = { [weak self] id in
            self?.editText(id)
        }
        canvas.onChange = { [weak self] _ in
            self?.updateTools()
        }
        insertSubview(canvas, aboveSubview: imageView)
        self.canvas = canvas
        setNeedsLayout()
    }

    func flattened() -> UIImage {
        let pixelWidth = image.size.width * image.scale
        guard let overlay = canvas.render(width: pixelWidth) else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale

        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            overlay.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    func apply(_ next: Mode) {
        if next == .crop, mode != .crop {
            image = flattened()
            imageView.image = image
            installCanvas()
            layoutIfNeeded()
            cropView.reset(ratio: Self.ratios[ratioIndex])
        }
        mode = next
        canvas.isDrawing = next == .draw
        cropView.isHidden = next != .crop
        canvas.isUserInteractionEnabled = next != .crop
        updateTools()
    }

    func applyCrop() {
        let crop = cropView.normalized
        let rect = CGRect(
            x: crop.minX * image.size.width,
            y: crop.minY * image.size.height,
            width: crop.width * image.size.width,
            height: crop.height * image.size.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        image = UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            image.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
        imageView.image = image
        Haptics.play(.success)
        apply(.idle)
        setNeedsLayout()
    }

    func rotate() {
        let size = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let source = image
        image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.rotate(by: -.pi / 2)
            source.draw(at: .zero)
        }
        imageView.image = image
        Haptics.play(.selection)
        setNeedsLayout()
        layoutIfNeeded()
        cropView.reset(ratio: Self.ratios[ratioIndex])
    }

    func editText(_ id: UUID?) {
        guard textEditor == nil, mode != .crop else {
            return
        }

        let done = strings.storiesDone
        textEditor = canvas.editText(id, in: self, color: palette.selected, doneTitle: done) { [weak self] in
            self?.textEditor = nil
        }
    }
}
