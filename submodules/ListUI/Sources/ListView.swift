@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class ListView: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private static let preloadDistance: CGFloat = 240
    private static let poolLimit = 24

    public let scrollView = UIScrollView()
    public var onScroll: (@MainActor (ListView) -> Void)?
    public var onWillEndDragging: (@MainActor (ListView, CGFloat) -> CGFloat)?

    public var theme: ListTheme {
        didSet {
            if theme != oldValue {
                invalidatePresentation()
            }
        }
    }

    public var contentInsets: UIEdgeInsets = .zero {
        didSet {
            guard contentInsets != oldValue else {
                return
            }

            let wasAtTop = abs(scrollView.contentOffset.y + oldValue.top) < 0.5
            scrollView.contentInset = contentInsets
            scrollView.verticalScrollIndicatorInsets = contentInsets
            restoreOffset(wasAtTop ? -contentInsets.top : scrollView.contentOffset.y)
        }
    }

    public var headerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let headerView, isNodeLoaded {
                scrollView.addSubview(headerView)
            }
            relayoutContent()
        }
    }

    public var headerHeight: CGFloat = 0 {
        didSet {
            if headerHeight != oldValue {
                relayoutContent()
            }
        }
    }

    public var allowsSwipeActions = false {
        didSet {
            swipe?.pan.isEnabled = allowsSwipeActions
            if !allowsSwipeActions {
                swipe?.close(animated: false)
            }
        }
    }

    let content = ASDisplayNode()
    var swipe: ListSwipeController?
    var items: [any ListItem] = []
    private var itemIDs: [String] = []
    private var frames: [CGRect] = []
    var active: [String: ListItemNode] = [:]
    private var pool: [String: [ListItemNode]] = [:]
    private var layoutWidth: CGFloat = 0

    public var contentOffset: CGFloat {
        scrollView.contentOffset.y
    }

    public init(theme: ListTheme) {
        self.theme = theme
        super.init()
    }

    override public func didLoad() {
        super.didLoad()
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.backgroundColor = theme.background
        scrollView.contentInset = contentInsets
        scrollView.verticalScrollIndicatorInsets = contentInsets
        view.addSubview(scrollView)
        scrollView.addSubview(content.view)
        if let headerView {
            scrollView.addSubview(headerView)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
        setupSwipe()
    }

    public func apply(items next: [any ListItem], animated: Bool = true) {
        let nextIDs = next.map(\.id)
        let transaction = ListTransaction(previous: itemIDs, next: nextIDs)
        let anchor = topAnchor()
        let animated = animated && !itemIDs.isEmpty

        items = next
        itemIDs = nextIDs
        guard isNodeLoaded, layoutWidth > 0 else {
            setNeedsLayout()

            return
        }

        rebuildFrames()
        if let anchor, let index = itemIDs.firstIndex(of: anchor.id) {
            restoreOffset(frames[index].minY - anchor.distance)
        } else {
            restoreOffset(scrollView.contentOffset.y)
        }

        for id in transaction.deleted {
            guard let node = active.removeValue(forKey: id) else {
                continue
            }

            node.view.isUserInteractionEnabled = false
            ListTransition.animate(animated) {
                node.view.alpha = 0
            } completion: { [weak self] _ in
                self?.recycle(node)
            }
        }
        ListTransition.animate(animated) { [weak self] in
            self?.updateVisible(inserted: transaction.inserted, animated: animated)
        }
    }

    override public func layout() {
        super.layout()
        guard bounds.width > 0 else {
            return
        }

        scrollView.frame = bounds
        if bounds.width != layoutWidth {
            layoutWidth = bounds.width
            rebuildFrames()
        }
        updateVisible()
    }

    private func relayoutContent() {
        guard isNodeLoaded, layoutWidth > 0 else {
            return
        }

        rebuildFrames()
        updateVisible()
    }

    private func rebuildFrames() {
        headerView?.frame = CGRect(x: 0, y: 0, width: layoutWidth, height: headerView == nil ? 0 : headerHeight)
        var y: CGFloat = headerView == nil ? 0 : headerHeight
        frames = items.map { item in
            let height = max(1, item.height(for: layoutWidth, theme: theme))
            let frame = CGRect(x: 0, y: y, width: layoutWidth, height: height)
            y += height

            return frame
        }
        content.frame = CGRect(x: 0, y: 0, width: layoutWidth, height: y)
        scrollView.contentSize = CGSize(width: layoutWidth, height: y)
    }

    private func restoreOffset(_ offset: CGFloat) {
        let minimum = -contentInsets.top
        let maximum = max(minimum, scrollView.contentSize.height + contentInsets.bottom - scrollView.bounds.height)
        scrollView.contentOffset.y = min(max(minimum, offset), maximum)
    }

    private func updateVisible(inserted: Set<String> = [], animated: Bool = false) {
        guard layoutWidth > 0, frames.count == items.count else {
            return
        }

        let indices = visibleIndices()
        let visibleIDs = Set(indices.map { index in
            itemIDs[index]
        })
        for id in Array(active.keys) where !visibleIDs.contains(id) {
            if let node = active.removeValue(forKey: id) {
                recycle(node)
            }
        }

        for index in indices {
            place(items[index], at: index, fadeIn: animated && inserted.contains(itemIDs[index]))
        }
    }

    private func place(_ item: any ListItem, at index: Int, fadeIn: Bool) {
        let id = itemIDs[index]
        if let existing = active[id], existing.reuseIdentifier == item.reuseIdentifier {
            configure(existing, item: item)
            if existing.frame != frames[index] {
                existing.frame = frames[index]
            }
            existing.view.alpha = 1

            return
        }

        if let old = active.removeValue(forKey: id) {
            recycle(old)
        }
        let node = pool[item.reuseIdentifier]?.popLast() ?? item.makeNode()
        node.reuseIdentifier = item.reuseIdentifier
        node.itemID = id
        node.view.isUserInteractionEnabled = true
        active[id] = node
        content.addSubnode(node)

        UIView.performWithoutAnimation {
            configure(node, item: item)
            node.frame = frames[index]
            node.view.alpha = fadeIn ? 0 : 1
            node.view.layoutIfNeeded()
        }
        node.view.alpha = 1
    }

    private func configure(_ node: ListItemNode, item: any ListItem) {
        guard node.appliedVersion != item.version || node.appliedWidth != layoutWidth else {
            return
        }

        item.update(node: node, theme: theme)
        node.appliedVersion = item.version
        node.appliedWidth = layoutWidth
        guard
            let asyncItem = item as? any AsyncListItem,
            node.preparedLayoutVersion != asyncItem.layoutVersion || node.preparedWidth != layoutWidth
        else {
            return
        }

        node.layoutGeneration += 1
        node.preparedLayoutVersion = asyncItem.layoutVersion
        node.preparedWidth = layoutWidth
        prepare(asyncItem, node: node)
    }

    private func prepare(_ item: any AsyncListItem, node: ListItemNode) {
        let generation = node.layoutGeneration
        let width = layoutWidth
        let theme = theme
        let scale = view.traitCollection.displayScale

        Task { [weak node] in
            let layout = await Task.detached(priority: .userInitiated) {
                item.prepareLayout(width: width, theme: theme, displayScale: scale)
            }.value
            guard let node, node.layoutGeneration == generation else {
                return
            }

            item.apply(layout, to: node)
        }
    }

    private func recycle(_ node: ListItemNode) {
        swipe?.nodeWillRecycle(node)
        node.removeFromSupernode()
        let kind = node.reuseIdentifier
        node.prepareForReuse()
        if pool[kind, default: []].count < Self.poolLimit {
            pool[kind, default: []].append(node)
        }
    }

    private func invalidatePresentation() {
        guard isNodeLoaded else {
            return
        }

        scrollView.backgroundColor = theme.background
        for node in active.values {
            node.appliedVersion = nil
            node.preparedLayoutVersion = nil
        }
        rebuildFrames()
        updateVisible()
    }
}

extension ListView {
    fileprivate func topAnchor() -> (id: String, distance: CGFloat)? {
        let offset = scrollView.contentOffset.y
        guard offset > -contentInsets.top else {
            return nil
        }

        let index = frames.firstIndex { frame in
            frame.maxY > offset
        }

        return index.map { index in
            (itemIDs[index], frames[index].minY - offset)
        }
    }

    fileprivate func visibleIndices() -> Range<Int> {
        let top = scrollView.contentOffset.y - Self.preloadDistance
        let bottom = scrollView.contentOffset.y + scrollView.bounds.height + Self.preloadDistance

        var low = 0
        var high = frames.count
        while low < high {
            let middle = (low + high) / 2
            if frames[middle].maxY < top {
                low = middle + 1
            } else {
                high = middle
            }
        }

        var end = low
        while end < frames.count, frames[end].minY <= bottom {
            end += 1
        }

        return low..<end
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging, swipe?.isOpen == true {
            swipe?.close(animated: true)
        }
        updateVisible()
        onScroll?(self)
    }

    public func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        if let onWillEndDragging {
            targetContentOffset.pointee.y = onWillEndDragging(self, targetContentOffset.pointee.y)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target, view !== scrollView {
            if view is UIControl {
                return false
            }

            target = view.superview
        }

        return true
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        if let swipe, swipe.isOpen {
            swipe.close(animated: true)

            return
        }

        let location = gesture.location(in: content.view)
        let node = active.values.first { node in
            node.frame.contains(location)
        }
        guard let id = node?.itemID, let item = items.first(where: { item in
            item.id == id
        }) else {
            return
        }

        item.selected()
    }
}

extension ListView {
    public func scrollToTop(animated: Bool) {
        scrollView.setContentOffset(CGPoint(x: 0, y: -contentInsets.top), animated: animated)
    }
}
