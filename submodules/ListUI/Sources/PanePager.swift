@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class PanePager: ASDisplayNode {
    public var onPosition: (@MainActor (CGFloat) -> Void)?
    public var onSelect: (@MainActor (Int) -> Void)?

    public private(set) var panes: [any ScrollablePane] = []
    public private(set) var selectedIndex = 0

    var onPaneChange: (@MainActor ((any ScrollablePane)?) -> Void)?
    var onPagingBegan: (@MainActor () -> Void)?

    private let pan = UIPanGestureRecognizer()
    private let panGate = PanGestureDelegate()
    private var tabsView: UIView?
    private var tabsHeight: CGFloat = 0
    private var pagePosition: CGFloat = 0
    private var startPosition: CGFloat = 0
    private var isSettling = false
    private var generation = 0

    public var currentPane: (any ScrollablePane)? {
        panes.indices.contains(selectedIndex) ? panes[selectedIndex] : nil
    }

    public var isPaging: Bool {
        isSettling || pan.state == .began || pan.state == .changed
    }

    override public func didLoad() {
        super.didLoad()
        view.clipsToBounds = true
        pan.maximumNumberOfTouches = 1
        panGate.shouldBegin = { [weak self] pan in
            self?.shouldBeginPaging(pan) ?? false
        }
        pan.delegate = panGate
        pan.addTarget(self, action: #selector(panned(_:)))
        view.addGestureRecognizer(pan)
        if let tabsView {
            view.addSubview(tabsView)
        }
    }

    public func setTabsView(_ tabsView: UIView, height: CGFloat) {
        self.tabsView?.removeFromSuperview()
        self.tabsView = tabsView
        tabsHeight = height
        if isNodeLoaded {
            view.addSubview(tabsView)
        }
        setNeedsLayout()
    }

    public func setPanes(_ panes: [any ScrollablePane]) {
        for pane in self.panes {
            pane.node.removeFromSupernode()
        }
        self.panes = panes
        for pane in panes {
            addSubnode(pane.node)
        }
        selectedIndex = min(selectedIndex, max(panes.count - 1, 0))
        pagePosition = CGFloat(selectedIndex)
        if let tabsView, isNodeLoaded {
            view.bringSubviewToFront(tabsView)
        }
        setNeedsLayout()
        onPaneChange?(currentPane)
    }

    public func select(_ index: Int, animated: Bool) {
        guard panes.indices.contains(index) else {
            return
        }

        generation += 1
        let current = generation
        isSettling = true
        pagePosition = CGFloat(index)
        ListTransition.animate(animated) { [weak self] in
            self?.placePanes()
        } completion: { [weak self] _ in
            guard let self, self.generation == current else {
                return
            }

            self.settle(at: index)
        }
    }

    func resetOffsets(except active: (any ScrollablePane)?) {
        for pane in panes where pane !== active && pane.verticalOffset != 0 {
            pane.setVerticalOffset(0)
        }
    }

    override public func layout() {
        super.layout()
        tabsView?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: tabsHeight)
        placePanes()
    }

    private func placePanes() {
        let height = max(0, bounds.height - tabsHeight)
        for (index, pane) in panes.enumerated() {
            let offset = CGFloat(index) - pagePosition
            pane.node.isHidden = abs(offset) >= 1
            pane.node.frame = CGRect(x: offset * bounds.width, y: tabsHeight, width: bounds.width, height: height)
        }
        onPosition?(pagePosition)
    }

    private func settle(at index: Int) {
        isSettling = false
        guard index != selectedIndex else {
            return
        }

        selectedIndex = index
        onPaneChange?(currentPane)
        onSelect?(index)
    }
}

extension PanePager {
    private func shouldBeginPaging(_ pan: UIPanGestureRecognizer) -> Bool {
        guard panes.count > 1, !isSettling, currentPane?.blocksPaging != true else {
            return false
        }

        let velocity = pan.velocity(in: view)
        let start = pan.location(in: view).y - pan.translation(in: view).y

        return abs(velocity.x) > abs(velocity.y) && start >= tabsHeight
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        guard bounds.width > 0 else {
            return
        }

        switch gesture.state {
        case .began:
            generation += 1
            onPagingBegan?()
            startPosition = CGFloat(selectedIndex)
        case .changed:
            let proposed = startPosition - gesture.translation(in: view).x / bounds.width
            let clamped = min(CGFloat(panes.count - 1), max(0, proposed))
            pagePosition = clamped + (proposed - clamped) * 0.18
            placePanes()
        case .ended, .cancelled, .failed:
            select(target(for: gesture), animated: true)
        default:
            break
        }
    }

    private func target(for gesture: UIPanGestureRecognizer) -> Int {
        guard gesture.state == .ended else {
            return selectedIndex
        }

        let velocity = gesture.velocity(in: view).x
        let translation = gesture.translation(in: view).x
        var direction = 0
        if abs(velocity) > 350 {
            direction = velocity < 0 ? 1 : -1
        } else if abs(translation) > bounds.width * 0.28 {
            direction = translation < 0 ? 1 : -1
        }

        return min(panes.count - 1, max(0, selectedIndex + direction))
    }
}
