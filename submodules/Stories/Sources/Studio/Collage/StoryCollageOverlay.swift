import Haptics
import UIKit

final class StoryCollageOverlay: UIView {
    var onChange: (@MainActor () -> Void)?

    private(set) var layout: StoryCollageLayout
    private(set) var images: [UIImage?]
    private let shade = CAShapeLayer()
    private let lines = CAShapeLayer()
    private let focus = CAShapeLayer()
    private let strip = UIScrollView()
    private var imageViews: [UIImageView] = []
    private var layoutButtons: [StoryCollageLayout: UIButton] = [:]

    init(layout: StoryCollageLayout) {
        self.layout = layout
        images = Array(repeating: nil, count: layout.cells.count)
        super.init(frame: .zero)
        shade.fillRule = .evenOdd
        shade.fillColor = UIColor(white: 0.06, alpha: 1).cgColor
        lines.fillColor = nil
        lines.strokeColor = UIColor(white: 1, alpha: 0.35).cgColor
        lines.lineWidth = 1
        focus.fillColor = nil
        focus.strokeColor = UIColor.white.cgColor
        focus.lineWidth = 2.5
        layer.addSublayer(shade)
        setUpStrip()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        rebuildImages()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var current: Int? {
        images.firstIndex { image in
            image == nil
        }
    }

    var isFull: Bool {
        current == nil
    }

    var currentCell: CGRect? {
        current.map { index in
            layout.cells[index]
        }
    }

    func setLayout(_ next: StoryCollageLayout) {
        let filled = images.compactMap(\.self)
        layout = next
        images = (0..<next.cells.count).map { index in
            filled.indices.contains(index) ? filled[index] : nil
        }
        rebuildImages()
        styleStrip()
        onChange?()
    }

    func fill(_ image: UIImage) {
        guard let current else {
            return
        }

        images[current] = image
        imageViews[current].image = image
        setNeedsLayout()
        onChange?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if strip.frame.contains(point) {
            return super.hitTest(point, with: event)
        }

        return filledIndex(at: point) == nil ? nil : self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = max(safeAreaInsets.top, 16) + 6 + 56
        strip.frame = CGRect(x: 0, y: top, width: bounds.width, height: 48)
        layoutStrip()
        for (index, cell) in layout.cells.enumerated() {
            imageViews[index].frame = rect(cell)
        }
        let shadePath = UIBezierPath(rect: bounds)
        let linesPath = UIBezierPath()
        for cell in layout.cells {
            linesPath.append(UIBezierPath(rect: rect(cell)))
        }
        if let currentCell {
            shadePath.append(UIBezierPath(rect: rect(currentCell)))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [shade, lines, focus] {
            layer.frame = bounds
        }
        shade.path = shadePath.cgPath
        lines.path = linesPath.cgPath
        focus.path = currentCell.map { cell in
            UIBezierPath(rect: rect(cell).insetBy(dx: 1.25, dy: 1.25)).cgPath
        }
        CATransaction.commit()
    }

    private func rect(_ cell: CGRect) -> CGRect {
        CGRect(
            x: cell.minX * bounds.width,
            y: cell.minY * bounds.height,
            width: cell.width * bounds.width,
            height: cell.height * bounds.height
        )
    }

    private func rebuildImages() {
        for view in imageViews {
            view.removeFromSuperview()
        }
        imageViews = images.map { image in
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.isUserInteractionEnabled = false
            insertSubview(view, belowSubview: strip)

            return view
        }
        lines.removeFromSuperlayer()
        focus.removeFromSuperlayer()
        layer.insertSublayer(lines, below: strip.layer)
        layer.insertSublayer(focus, below: strip.layer)
        setNeedsLayout()
    }

    private func filledIndex(at point: CGPoint) -> Int? {
        layout.cells.indices.first { index in
            images[index] != nil && rect(layout.cells[index]).contains(point)
        }
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        guard let index = filledIndex(at: gesture.location(in: self)) else {
            return
        }

        Haptics.play(.tap)
        images[index] = nil
        imageViews[index].image = nil
        setNeedsLayout()
        onChange?()
    }
}

extension StoryCollageOverlay {
    private func setUpStrip() {
        strip.showsHorizontalScrollIndicator = false
        addSubview(strip)
        for option in StoryCollageLayout.allCases {
            let button = UIButton(type: .custom)
            button.setImage(StoryCollage.icon(option, side: 26), for: .normal)
            button.layer.cornerRadius = 12
            button.layer.cornerCurve = .continuous
            button.addAction(UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.setLayout(option)
            }, for: .touchUpInside)
            strip.addSubview(button)
            layoutButtons[option] = button
        }
        styleStrip()
    }

    private func layoutStrip() {
        let side: CGFloat = 44
        let count = CGFloat(StoryCollageLayout.allCases.count)
        let total = count * side + (count - 1) * 8
        var x = max(16, (bounds.width - total) / 2)
        for option in StoryCollageLayout.allCases {
            layoutButtons[option]?.frame = CGRect(x: x, y: 2, width: side, height: side)
            x += side + 8
        }
        strip.contentSize = CGSize(width: x + 8, height: 48)
    }

    private func styleStrip() {
        for (option, button) in layoutButtons {
            button.backgroundColor = option == layout ? UIColor(white: 1, alpha: 0.32) : UIColor(white: 0, alpha: 0.4)
        }
    }
}
