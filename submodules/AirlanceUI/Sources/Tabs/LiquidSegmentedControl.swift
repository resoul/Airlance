import Haptics
import LiquidUI
import Theme
import UIKit

public struct LiquidSegmentedStyle {
    public let font: UIFont
    public let text: UIColor
    public let selectedText: UIColor
    public let background: UIColor
    public let accent: UIColor

    public init(font: UIFont, text: UIColor, selectedText: UIColor, background: UIColor, accent: UIColor) {
        self.font = font
        self.text = text
        self.selectedText = selectedText
        self.background = background
        self.accent = accent
    }

    public init(theme: AppTheme) {
        self.init(
            font: theme.fonts.subheadline,
            text: theme.colors.textPrimary,
            selectedText: theme.colors.onAccent,
            background: theme.colors.surface,
            accent: theme.colors.accent
        )
    }
}

@MainActor
public final class LiquidSegmentedControl: UIView {
    public static let height: CGFloat = 36

    private static let inset: CGFloat = 3
    private static let padding: CGFloat = 14
    private static let fadeWidth: CGFloat = 18

    public var onSelect: (@MainActor (Int) -> Void)?
    public private(set) var selectedIndex = 0

    private let capsule = UIView()
    private let selection = LiquidSelectionView()
    private let stripHost = UIView()
    private let strip = UIView()
    private let fade = CAGradientLayer()
    private var widthLimit: CGFloat?
    private var labels: [UILabel] = []
    private var titles: [String] = []
    private var style: LiquidSegmentedStyle?
    private var dragIndex: Int?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        capsule.layer.cornerCurve = .continuous
        capsule.isUserInteractionEnabled = false
        addSubview(capsule)
        capsule.addSubview(stripHost)
        stripHost.addSubview(strip)
        strip.addSubview(selection)
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public var intrinsicContentSize: CGSize {
        let width = segmentWidths.reduce(Self.inset * 2, +)

        return CGSize(width: min(widthLimit ?? width, width), height: Self.height)
    }

    public func limitWidth(to width: CGFloat) {
        guard width != widthLimit else {
            return
        }

        widthLimit = width
        stripHost.layer.mask = fade
        invalidateIntrinsicContentSize()
        sizeToFit()
        setNeedsLayout()
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    public func setTitles(_ titles: [String]) {
        guard titles != self.titles else {
            return
        }

        if titles.count != labels.count {
            labels.forEach { label in
                label.removeFromSuperview()
            }
            labels = titles.map { _ in
                let label = UILabel()
                label.textAlignment = .center
                label.isAccessibilityElement = true
                strip.addSubview(label)

                return label
            }
        }
        self.titles = titles
        updateLabels()
        invalidateIntrinsicContentSize()
        sizeToFit()
        setNeedsLayout()
    }

    public func apply(_ theme: AppTheme) {
        apply(style: LiquidSegmentedStyle(theme: theme))
    }

    public func apply(style: LiquidSegmentedStyle) {
        self.style = style
        capsule.backgroundColor = style.background
        selection.color = style.accent
        updateLabels()
        invalidateIntrinsicContentSize()
        sizeToFit()
        setNeedsLayout()
    }

    public func select(_ index: Int, animated: Bool) {
        let changed = index != selectedIndex
        selectedIndex = index
        selection.select(index, animated: animated)
        updateLabels()
        moveStrip(animated: changed && animated)
        if changed, animated {
            bounce(at: index)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        capsule.frame = bounds
        capsule.layer.cornerRadius = bounds.height / 2
        stripHost.frame = capsule.bounds
        var x = Self.inset
        var slots: [CGRect] = []
        for (label, width) in zip(labels, segmentWidths) {
            let frame = CGRect(x: x, y: Self.inset, width: width, height: bounds.height - Self.inset * 2)
            label.bounds = CGRect(origin: .zero, size: frame.size)
            label.center = CGPoint(x: frame.midX, y: frame.midY)
            slots.append(frame)
            x += width
        }
        strip.bounds = CGRect(x: 0, y: 0, width: max(x + Self.inset, bounds.width), height: bounds.height)
        selection.frame = strip.bounds
        selection.slots = slots
        moveStrip(animated: false)
    }

    private var stripOriginX: CGFloat {
        let hidden = strip.bounds.width - bounds.width
        guard hidden > 0, selection.slots.indices.contains(selectedIndex) else {
            return 0
        }

        return min(0, max(bounds.midX - selection.slots[selectedIndex].midX, -hidden))
    }

    private func moveStrip(animated: Bool) {
        let isAnimated = animated && !UIAccessibility.isReduceMotionEnabled
        layoutFade(animated: isAnimated)
        let place = {
            self.strip.frame.origin = CGPoint(x: self.stripOriginX, y: 0)
        }
        guard isAnimated else {
            place()

            return
        }

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: place
        )
    }

    private func layoutFade(animated: Bool) {
        guard widthLimit != nil, bounds.width > 0 else {
            return
        }

        let edge = Double(Self.fadeWidth / bounds.width)
        let origin = stripOriginX
        let leading = origin < 0 ? edge : 0
        let trailing = origin > bounds.width - strip.bounds.width ? edge : 0
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        fade.frame = stripHost.bounds
        fade.locations = [0, NSNumber(value: leading), NSNumber(value: 1 - trailing), 1]
        CATransaction.commit()
    }

    private var segmentWidths: [CGFloat] {
        let font = style?.font ?? .preferredFont(forTextStyle: .subheadline)

        return titles.map { title in
            ceil((title as NSString).size(withAttributes: [.font: font]).width) + Self.padding * 2
        }
    }

    private func updateLabels() {
        guard let style else {
            return
        }

        let highlighted = dragIndex ?? selectedIndex
        for (index, label) in labels.enumerated() where titles.indices.contains(index) {
            let isSelected = index == highlighted
            label.attributedText = NSAttributedString(string: titles[index], attributes: [
                .font: style.font,
                .foregroundColor: isSelected ? style.selectedText : style.text,
            ])
            label.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func bounce(at index: Int) {
        guard labels.indices.contains(index), !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        let label = labels[index]
        label.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            label.transform = .identity
        }
    }

    private func index(at point: CGPoint) -> Int? {
        selection.slots.firstIndex { slot in
            point.x >= slot.minX && point.x < slot.maxX
        } ?? (point.x < Self.inset ? 0 : (labels.isEmpty ? nil : labels.count - 1))
    }

    private func position(at point: CGPoint) -> CGFloat? {
        let slots = selection.slots
        guard let first = slots.first, let last = slots.last else {
            return nil
        }

        let x = min(max(point.x, first.midX), last.midX)
        guard let next = slots.firstIndex(where: { slot in
            slot.midX >= x
        }), next > 0 else {
            return 0
        }

        let previous = slots[next - 1]
        let span = max(slots[next].midX - previous.midX, 1)

        return CGFloat(next - 1) + (x - previous.midX) / span
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        guard let index = index(at: gesture.location(in: strip)) else {
            return
        }

        Haptics.play(.selection)
        onSelect?(index)
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: strip)
        switch gesture.state {
        case .began, .changed:
            if gesture.state == .began {
                Haptics.prepare(.selection)
            }
            selection.setInteractivePosition(position(at: point))
            let index = index(at: point)
            if index != dragIndex, index != nil {
                dragIndex = index
                Haptics.play(.selection)
                updateLabels()
            }
        case .ended:
            let index = dragIndex
            finishDrag()
            if let index {
                onSelect?(index)
            }
        default:
            finishDrag()
        }
    }

    private func finishDrag() {
        dragIndex = nil
        selection.setInteractivePosition(nil)
        updateLabels()
    }
}
