import Haptics
import LiquidUI
import Theme
import UIKit

@MainActor
public final class TabBarView: UIView {
    public var onSelect: (@MainActor (Int) -> Void)?
    public var menuProvider: (@MainActor (Int) -> [PopupMenuItem]?)? {
        didSet {
            updateMenuGesture()
        }
    }

    public private(set) var selectedIndex = 0

    let background = UIView()
    private let selection = LiquidSelectionView()
    private let compactAnimator = SpringAnimator(value: 0, stiffness: 16, dampingRatio: 0.82)
    private var items: [TabBarItem] = []
    var iconViews: [UIImageView] = []
    var theme: AppTheme?
    lazy var menuGesture = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
    private var layout: TabBarLayout?
    private var dragIndex: Int?

    public var isCompact: Bool {
        compactAnimator.value > 0.5
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        background.layer.shadowOpacity = 0.12
        background.layer.shadowRadius = 16
        background.layer.shadowOffset = CGSize(width: 0, height: 4)
        background.layer.borderWidth = 1 / UIScreen.main.scale
        addSubview(background)
        background.addSubview(selection)

        compactAnimator.onChange = { [weak self] _ in
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
        }
        background.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        background.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        menuGesture.minimumPressDuration = 0.4
        menuGesture.isEnabled = false
        background.addGestureRecognizer(menuGesture)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func setItems(_ items: [TabBarItem]) {
        let rebuild = items.count != iconViews.count
        self.items = items
        if rebuild {
            iconViews.forEach { view in
                view.removeFromSuperview()
            }
            iconViews = items.map { _ in
                let view = UIImageView()
                view.contentMode = .center
                view.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
                background.addSubview(view)

                return view
            }
            setNeedsLayout()
        }
        updateIcons()
    }

    public func select(_ index: Int, animated: Bool) {
        guard items.indices.contains(index) else {
            return
        }

        let changed = index != selectedIndex
        selectedIndex = index
        selection.select(index, animated: animated)
        updateIcons()
        if changed, animated {
            bounceIcon(at: index)
        }
    }

    public func setCompact(_ compact: Bool, animated: Bool) {
        let target: CGFloat = compact ? 1 : 0
        if animated {
            compactAnimator.animate(to: target)
        } else {
            compactAnimator.set(target)
        }
    }

    public func apply(_ theme: AppTheme) {
        self.theme = theme
        background.backgroundColor = theme.colors.surface
        background.layer.borderColor = theme.colors.separator.cgColor
        background.layer.shadowColor = UIColor.black.cgColor
        selection.color = theme.colors.accent
        updateIcons()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let layout = TabBarLayout.make(
            bounds: bounds,
            bottomInset: safeAreaInsets.bottom,
            count: items.count,
            compactProgress: compactAnimator.value
        )
        self.layout = layout

        background.frame = layout.barFrame
        background.layer.cornerRadius = layout.barFrame.height / 2
        background.layer.shadowPath = UIBezierPath(
            roundedRect: background.bounds,
            cornerRadius: background.layer.cornerRadius
        ).cgPath
        selection.frame = background.bounds
        selection.slots = layout.itemFrames.map { frame in
            frame.insetBy(dx: 2, dy: 0)
        }
        for (view, frame) in zip(iconViews, layout.itemFrames) {
            view.bounds = CGRect(origin: .zero, size: frame.size)
            view.center = CGPoint(x: frame.midX, y: frame.midY)
            view.transform = CGAffineTransform(scaleX: layout.iconScale, y: layout.iconScale)
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard background.frame.contains(point) else {
            return nil
        }

        return super.hitTest(point, with: event)
    }

    private func updateIcons() {
        let highlighted = dragIndex ?? selectedIndex
        for (index, view) in iconViews.enumerated() {
            let item = items[index]
            let isSelected = index == highlighted
            view.image = isSelected ? item.selectedImage ?? item.image : item.image
            view.accessibilityLabel = item.title
            view.accessibilityTraits = isSelected ? [.button, .selected] : .button
            view.isAccessibilityElement = true
            if let theme {
                view.tintColor = isSelected ? theme.colors.onAccent : theme.colors.textPrimary
            }
        }
    }

    private func bounceIcon(at index: Int) {
        guard let layout, iconViews.indices.contains(index), !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        let view = iconViews[index]
        let scale = layout.iconScale
        view.transform = CGAffineTransform(scaleX: scale * 0.78, y: scale * 0.78)
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    func index(at point: CGPoint) -> Int? {
        layout?.itemFrames.firstIndex { frame in
            point.x >= frame.minX && point.x < frame.maxX
        }
    }

    private func position(at point: CGPoint) -> CGFloat? {
        guard let frames = layout?.itemFrames, let first = frames.first else {
            return nil
        }

        return (point.x - first.midX) / first.width
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        guard let index = index(at: gesture.location(in: background)) else {
            return
        }

        onSelect?(index)
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: background)

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
                updateIcons()
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
        updateIcons()
    }
}
