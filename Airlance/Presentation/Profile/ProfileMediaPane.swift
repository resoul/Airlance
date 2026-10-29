@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

final class ProfileMediaPane: ScrollablePane {
    let grid = ProfileMediaGrid(count: 72)

    var onGeometryChange: (@MainActor () -> Void)?
    var onOffsetChange: (@MainActor () -> Void)?

    private(set) var verticalOffset: CGFloat = 0
    private let mediaNode: ProfileMediaNode
    private var contentHeight: CGFloat = 0
    private var size = CGSize.zero

    var bottomInset: CGFloat = 0 {
        didSet {
            if bottomInset != oldValue {
                onGeometryChange?()
            }
        }
    }

    var node: ASDisplayNode {
        mediaNode
    }

    var maximumVerticalOffset: CGFloat {
        max(0, contentHeight + bottomInset - size.height)
    }

    var blocksPaging: Bool {
        grid.pinch.state == .began || grid.pinch.state == .changed
    }

    var month: Int {
        grid.month(at: max(0, verticalOffset))
    }

    init() {
        mediaNode = ProfileMediaNode(grid: grid)
        mediaNode.onLayout = { [weak self] in
            self?.updateGeometry()
        }
        grid.onHeightChange = { [weak self] in
            self?.updateGeometry()
        }
    }

    func setVerticalOffset(_ offset: CGFloat) {
        guard offset.isFinite, offset != verticalOffset else {
            return
        }

        verticalOffset = offset
        placeGrid()
        onOffsetChange?()
    }

    private func updateGeometry() {
        let bounds = mediaNode.bounds.size
        guard bounds.width > 0 else {
            return
        }

        let height = grid.contentHeight(for: bounds.width)
        let changed = height != contentHeight || bounds != size
        contentHeight = height
        size = bounds
        placeGrid()
        if changed {
            onGeometryChange?()
        }
    }

    private func placeGrid() {
        grid.frame = CGRect(x: 0, y: -verticalOffset, width: size.width, height: contentHeight)
    }
}

private final class ProfileMediaNode: ASDisplayNode {
    var onLayout: (@MainActor () -> Void)?

    private let grid: UIView

    init(grid: UIView) {
        self.grid = grid
        super.init()
    }

    override func didLoad() {
        super.didLoad()
        view.clipsToBounds = true
        view.addSubview(grid)
    }

    override func layout() {
        super.layout()
        onLayout?()
    }
}
