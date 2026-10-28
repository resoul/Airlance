@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class ListPager: ASDisplayNode, UIScrollViewDelegate {
    public let scrollView = UIScrollView()
    public var onPosition: (@MainActor (CGFloat) -> Void)?
    public var onSelect: (@MainActor (Int) -> Void)?

    public private(set) var lists: [ListView] = []
    public private(set) var selectedIndex = 0

    public var theme: ListTheme {
        didSet {
            for list in lists {
                list.theme = theme
            }
        }
    }

    public var contentInsets: UIEdgeInsets = .zero {
        didSet {
            for list in lists {
                list.contentInsets = contentInsets
            }
        }
    }

    public var currentList: ListView? {
        lists.indices.contains(selectedIndex) ? lists[selectedIndex] : nil
    }

    private var pageWidth: CGFloat = 0

    public init(theme: ListTheme) {
        self.theme = theme
        super.init()
    }

    override public func didLoad() {
        super.didLoad()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.scrollsToTop = false
        scrollView.delegate = self
        view.addSubview(scrollView)
        for list in lists {
            scrollView.addSubview(list.view)
        }
    }

    public func setPageCount(_ count: Int) {
        guard count != lists.count else {
            return
        }

        for list in lists {
            list.view.removeFromSuperview()
        }
        lists = (0..<count).map { _ in
            let list = ListView(theme: theme)
            list.contentInsets = contentInsets
            list.scrollView.scrollsToTop = false

            return list
        }
        if isNodeLoaded {
            for list in lists {
                scrollView.addSubview(list.view)
            }
        }
        selectedIndex = min(selectedIndex, max(count - 1, 0))
        updateSelection()
        setNeedsLayout()
    }

    public func select(_ index: Int, animated: Bool) {
        guard lists.indices.contains(index), pageWidth > 0 else {
            selectedIndex = index
            updateSelection()

            return
        }

        let passed = min(index, selectedIndex)...max(index, selectedIndex)
        for page in passed {
            lists[page].isSuspended = false
        }
        scrollView.setContentOffset(CGPoint(x: CGFloat(index) * pageWidth, y: 0), animated: animated)
        if !animated {
            settle()
        }
    }

    override public func layout() {
        super.layout()
        scrollView.frame = bounds
        guard bounds.width > 0 else {
            return
        }

        pageWidth = bounds.width
        for (index, list) in lists.enumerated() {
            list.frame = CGRect(x: CGFloat(index) * pageWidth, y: 0, width: pageWidth, height: bounds.height)
        }
        scrollView.contentSize = CGSize(width: pageWidth * CGFloat(lists.count), height: bounds.height)
        if !scrollView.isDragging, !scrollView.isDecelerating {
            scrollView.contentOffset = CGPoint(x: CGFloat(selectedIndex) * pageWidth, y: 0)
        }
    }

    private func settle() {
        guard pageWidth > 0, !lists.isEmpty else {
            return
        }

        let index = min(max(Int((scrollView.contentOffset.x / pageWidth).rounded()), 0), lists.count - 1)
        guard index != selectedIndex else {
            return
        }

        selectedIndex = index
        updateSelection()
        onSelect?(index)
    }

    private func updateSelection() {
        for (index, list) in lists.enumerated() {
            list.scrollView.scrollsToTop = index == selectedIndex
            list.isOnScreen = index == selectedIndex
            list.isSuspended = abs(index - selectedIndex) > 1
        }
    }
}

extension ListPager {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard pageWidth > 0 else {
            return
        }

        onPosition?(scrollView.contentOffset.x / pageWidth)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settle()
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settle()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            settle()
        }
    }
}
