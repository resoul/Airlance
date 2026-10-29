import Haptics
import LiquidUI
import UIKit

final class ProfileMediaGrid: UIView {
    static let perMonth = 12

    var onHeightChange: (@MainActor () -> Void)?

    let pinch = UIPinchGestureRecognizer()

    private let gap: CGFloat = 1.5
    private var cells: [UIImageView] = []
    private var columns: CGFloat = 3
    private var pinchStart: CGFloat = 3
    private var target: CGFloat = 3
    private var spring = Spring(3, stiffness: 14, dampingRatio: 0.8)
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    init(count: Int) {
        super.init(frame: .zero)
        clipsToBounds = true
        let size = CGSize(width: 160, height: 160)
        cells = (0..<count).map { index in
            let cell = UIImageView(image: StoryArt.render(seed: index * 7 + 3, size: size))
            cell.contentMode = .scaleAspectFill
            cell.clipsToBounds = true
            cell.isAccessibilityElement = true
            cell.accessibilityTraits = .image
            addSubview(cell)

            return cell
        }
        pinch.addTarget(self, action: #selector(pinched(_:)))
        addGestureRecognizer(pinch)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setAccessibilityLabels(_ label: (Int) -> String) {
        for (index, cell) in cells.enumerated() {
            cell.accessibilityLabel = label(index + 1)
        }
    }

    func contentHeight(for width: CGFloat) -> CGFloat {
        let (low, high, fraction) = blend()

        return height(columns: low, width: width) * (1 - fraction) + height(columns: high, width: width) * fraction
    }

    func month(at offset: CGFloat) -> Int {
        let count = Int(columns.rounded())
        let row = Int(offset / (cellSize(count, width: bounds.width) + gap))

        return row * count / Self.perMonth
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let (low, high, fraction) = blend()
        for (index, cell) in cells.enumerated() {
            let from = frame(index, columns: low)
            let to = frame(index, columns: high)
            cell.frame = CGRect(
                x: from.minX + (to.minX - from.minX) * fraction,
                y: from.minY + (to.minY - from.minY) * fraction,
                width: from.width + (to.width - from.width) * fraction,
                height: from.height + (to.height - from.height) * fraction
            )
        }
    }

    private func blend() -> (Int, Int, CGFloat) {
        let low = Int(columns.rounded(.down))

        return (low, Int(columns.rounded(.up)), columns - CGFloat(low))
    }

    private func cellSize(_ columns: Int, width: CGFloat) -> CGFloat {
        (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func frame(_ index: Int, columns: Int) -> CGRect {
        let size = cellSize(columns, width: bounds.width)

        return CGRect(
            x: CGFloat(index % columns) * (size + gap),
            y: CGFloat(index / columns) * (size + gap),
            width: size,
            height: size
        )
    }

    private func height(columns: Int, width: CGFloat) -> CGFloat {
        let rows = (cells.count + columns - 1) / columns

        return CGFloat(rows) * (cellSize(columns, width: width) + gap)
    }

    private func setColumns(_ value: CGFloat) {
        columns = value
        setNeedsLayout()
        onHeightChange?()
    }

    @objc
    private func pinched(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            driver.stop()
            pinchStart = columns
        case .changed:
            var value = pinchStart / max(gesture.scale, 0.01)
            if value < 2 {
                value = 2 - (2 - value) * 0.3
            } else if value > 6 {
                value = 6 + (value - 6) * 0.3
            }
            setColumns(min(max(value, 1.6), 6.6))
        case .ended, .cancelled, .failed:
            target = min(max(columns.rounded(), 2), 6)
            if target != pinchStart.rounded() {
                Haptics.play(.selection)
            }
            spring.reset(to: columns)
            driver.start()
        default:
            break
        }
    }

    private func step(_ deltaTime: CFTimeInterval) {
        spring.step(toward: target, deltaTime: deltaTime)
        let settled = spring.isSettled(at: target)
        setColumns(settled ? target : min(max(spring.value, 1.6), 6.6))
        if settled {
            driver.stop()
        }
    }
}
