@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class ListView: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    static let preloadDistance: CGFloat = 240
    static let poolLimit = 24
    private static let layoutCacheLimit = 96

    public let scrollView = UIScrollView()
    public let overlayView = UIView()
    public var onScroll: (@MainActor (ListView) -> Void)?
    public var onWillEndDragging: (@MainActor (ListView, CGFloat) -> CGFloat)?
    public var onContentSizeChange: (@MainActor (ListView) -> Void)?
    public var onLongPressMove: (@MainActor (UILongPressGestureRecognizer) -> Void)?

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
            let distance = distanceFromBottom(insets: oldValue)
            scrollView.contentInset = contentInsets
            scrollView.verticalScrollIndicatorInsets = contentInsets
            guard anchorsToBottom else {
                restoreOffset(wasAtTop ? -contentInsets.top : scrollView.contentOffset.y)

                return
            }

            keepBottom(distance: distance)
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

    public var isSuspended = false {
        didSet {
            if isSuspended != oldValue, !isSuspended {
                placedRange = nil
                updateVisible()
            }
        }
    }

    public var anchorsToBottom = false {
        didSet {
            if anchorsToBottom != oldValue {
                keepBottom(distance: 0)
            }
        }
    }

    public var isOnScreen = true {
        didSet {
            if isOnScreen != oldValue {
                updateShown()
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
    var itemIDs: [String] = []
    var entries: [ListEntry] = []
    var active: [String: ListItemNode] = [:]
    var layoutWidth: CGFloat = 0
    let layouts = ListLayoutCache(limit: ListView.layoutCacheLimit)
    var frames: [CGRect] = []
    var pool: [String: [ListItemNode]] = [:]
    var placedRange: Range<Int>?
    var prefetchedRange: Range<Int>?
    var pendingAnchor: ListAnchor?
    var preparations: [String: ListPreparation] = [:]
    var shownRange: Range<Int>?

    public var contentOffset: CGFloat {
        scrollView.contentOffset.y
    }

    public init(theme: ListTheme) {
        self.theme = theme
        super.init()
        scrollView.keyboardDismissMode = .onDrag
    }

    override public func didLoad() {
        super.didLoad()
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        scrollView.backgroundColor = theme.background
        scrollView.contentInset = contentInsets
        scrollView.verticalScrollIndicatorInsets = contentInsets
        view.addSubview(scrollView)
        scrollView.addSubview(content.view)
        overlayView.isUserInteractionEnabled = false
        scrollView.addSubview(overlayView)
        if let headerView {
            scrollView.addSubview(headerView)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
        setupSwipe()
        setupLongPress()
    }

    public func apply(items next: [any ListItem], animated: Bool = true) {
        let nextIDs = next.map(\.id)
        let transaction = ListTransaction(previous: itemIDs, next: nextIDs)
        let anchor = topAnchor()
        let animated = animated && !itemIDs.isEmpty
        let wasAtBottom = anchorsToBottom && (frames.isEmpty || distanceFromBottom(insets: contentInsets) < 8)

        items = next
        itemIDs = nextIDs
        entries = next.map { item in
            ListEntry(item)
        }
        placedRange = nil
        guard isNodeLoaded, layoutWidth > 0 else {
            setNeedsLayout()

            return
        }

        let positions = screenPositions()
        rebuildFrames()
        restorePosition(wasAtBottom: wasAtBottom, anchor: anchor)

        keepOnScreen(transaction.deleted, positions: positions)
        fadeOut(transaction.deleted, animated: animated)
        settle(from: positions, inserted: transaction.inserted, animated: animated)
    }

    override public func layout() {
        super.layout()
        guard bounds.width > 0 else {
            return
        }

        let distance = distanceFromBottom(insets: contentInsets)
        let heightChanged = scrollView.bounds.height != bounds.height
        scrollView.frame = bounds
        if bounds.width != layoutWidth {
            layoutWidth = bounds.width
            resetLayouts()
            rebuildFrames()
            if !applyPendingAnchor(), anchorsToBottom {
                restoreOffset(maximumOffset(insets: contentInsets) - distance)
            }
        } else if anchorsToBottom, heightChanged {
            keepBottom(distance: distance)
        }
        updateVisible()
    }

    func relayoutContent() {
        guard isNodeLoaded, layoutWidth > 0 else {
            return
        }

        rebuildFrames()
        updateVisible()
    }

    private func rebuildFrames() {
        headerView?.frame = CGRect(x: 0, y: 0, width: layoutWidth, height: headerView == nil ? 0 : headerHeight)
        var y: CGFloat = headerView == nil ? 0 : headerHeight
        placedRange = nil
        prefetchedRange = nil
        frames = items.map { item in
            let height = max(1, item.height(for: layoutWidth, theme: theme))
            let frame = CGRect(x: 0, y: y, width: layoutWidth, height: height)
            y += height

            return frame
        }
        let fill = bottomFill(contentHeight: y)
        if fill > 0 {
            frames = frames.map { frame in
                frame.offsetBy(dx: 0, dy: fill)
            }
            y += fill
        }
        content.frame = CGRect(x: 0, y: 0, width: layoutWidth, height: y)
        overlayView.frame = content.frame
        let changed = scrollView.contentSize.height != y
        scrollView.contentSize = CGSize(width: layoutWidth, height: y)
        if changed {
            onContentSizeChange?(self)
        }
    }

    private func invalidatePresentation() {
        guard isNodeLoaded else {
            return
        }

        scrollView.backgroundColor = theme.background
        resetLayouts()
        for node in active.values {
            node.appliedVersion = nil
            node.preparedLayoutVersion = nil
        }
        rebuildFrames()
        updateVisible()
    }
}

extension ListView {
    fileprivate func restorePosition(wasAtBottom: Bool, anchor: (id: String, distance: CGFloat)?) {
        guard !applyPendingAnchor() else {
            return
        }

        if wasAtBottom {
            restoreOffset(.greatestFiniteMagnitude)
        } else if let anchor, let index = itemIDs.firstIndex(of: anchor.id) {
            restoreOffset(frames[index].minY - anchor.distance)
        } else {
            restoreOffset(scrollView.contentOffset.y)
        }
    }

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

    func updateShown() {
        let range = isOnScreen && isNodeLoaded ? visibleIndices(margin: 0) : 0..<0
        guard range != shownRange else {
            return
        }

        shownRange = range
        guard let placedRange, placedRange.upperBound <= itemIDs.count else {
            return
        }

        for index in placedRange {
            active[itemIDs[index]]?.isOnScreen = range.contains(index)
        }
    }

    func visibleIndices(margin: CGFloat) -> Range<Int> {
        let top = scrollView.contentOffset.y - margin
        let bottom = scrollView.contentOffset.y + scrollView.bounds.height + margin

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
        guard let node, let id = node.itemID, let item = items.first(where: { item in
            item.id == id
        }) else {
            return
        }

        item.tapped(node: node, at: CGPoint(x: location.x - node.frame.minX, y: location.y - node.frame.minY))
    }
}

extension ListView {
    func restoreOffset(_ offset: CGFloat) {
        let minimum = -contentInsets.top
        scrollView.contentOffset.y = min(max(minimum, offset), maximumOffset(insets: contentInsets))
    }

    public func scrollToTop(animated: Bool) {
        scrollView.setContentOffset(CGPoint(x: 0, y: -contentInsets.top), animated: animated)
    }
}
