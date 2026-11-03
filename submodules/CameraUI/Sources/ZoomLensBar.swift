import LiquidUI
import UIKit

final class ZoomLensBar: UIView {
    static let pill: CGFloat = 38
    static let gap: CGFloat = 6
    static let inset: CGFloat = 4

    var onSelect: (@MainActor (CGFloat) -> Void)?
    var onStep: (@MainActor (Int) -> Void)?

    private(set) var stops: [CGFloat] = []
    private let selection = LiquidSelectionView()
    private var labels: [UILabel] = []
    private var zoom: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        selection.color = UIColor(white: 0.08, alpha: 1)
        addSubview(selection)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var width: CGFloat {
        let count = CGFloat(stops.count)

        return count * Self.pill + max(count - 1, 0) * Self.gap + Self.inset * 2
    }

    func configure(stops: [CGFloat], zoom: CGFloat) {
        self.stops = stops
        for label in labels {
            label.removeFromSuperview()
        }
        labels = stops.map { _ in
            let label = UILabel()
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            addSubview(label)

            return label
        }
        setNeedsLayout()
        layoutIfNeeded()
        update(zoom: zoom)
    }

    func update(zoom: CGFloat) {
        self.zoom = zoom
        let position = position(of: zoom)
        selection.setInteractivePosition(position)
        let active = Int(position.rounded())
        for (index, label) in labels.enumerated() {
            let isActive = index == active
            let value = isActive ? zoom : stops[index]
            label.text = Self.format(value) + (isActive ? "×" : "")
            label.textColor = isActive ? .systemYellow : .white
            label.font = .systemFont(ofSize: isActive ? 13 : 12, weight: .bold)
        }
        accessibilityValue = Self.format(zoom) + "×"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        selection.frame = bounds
        var slots: [CGRect] = []
        for (index, label) in labels.enumerated() {
            let x = Self.inset + CGFloat(index) * (Self.pill + Self.gap)
            label.frame = CGRect(x: x, y: (bounds.height - Self.pill) / 2, width: Self.pill, height: Self.pill)
            slots.append(label.frame)
        }
        selection.slots = slots
    }

    override func accessibilityIncrement() {
        onStep?(1)
    }

    override func accessibilityDecrement() {
        onStep?(-1)
    }

    static func format(_ value: CGFloat) -> String {
        abs(value - value.rounded()) < 0.05 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func position(of zoom: CGFloat) -> CGFloat {
        guard let first = stops.first, let last = stops.last, zoom > first else {
            return 0
        }
        guard zoom < last else {
            return CGFloat(stops.count - 1)
        }

        let upper = stops.firstIndex { stop in
            stop > zoom
        } ?? stops.count - 1
        let lower = max(upper - 1, 0)

        return CGFloat(lower) + log(zoom / stops[lower]) / log(stops[upper] / stops[lower])
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let nearest = labels.indices.min { first, second in
            abs(labels[first].center.x - point.x) < abs(labels[second].center.x - point.x)
        }
        guard let nearest else {
            return
        }

        onSelect?(stops[nearest])
    }
}
