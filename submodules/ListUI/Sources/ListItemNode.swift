@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
open class ListItemNode: ASDisplayNode {
    public internal(set) var itemID: String?
    public internal(set) var isOnScreen = false {
        didSet {
            if isOnScreen != oldValue {
                visibilityChanged()
            }
        }
    }

    var appliedVersion: Int?
    var appliedWidth: CGFloat = 0
    var reuseIdentifier = ""
    var layoutGeneration = 0
    var preparedLayoutVersion: Int?
    var preparedWidth: CGFloat = 0
    var layoutTask: Task<(any ListPreparedLayout)?, Never>?

    override open func didLoad() {
        super.didLoad()
        view.clipsToBounds = true
    }

    open func visibilityChanged() {
    }

    open func prepareForReuse() {
        itemID = nil
        isOnScreen = false
        layoutGeneration += 1
        layoutTask?.cancel()
        layoutTask = nil
        preparedLayoutVersion = nil
        preparedWidth = 0
        appliedVersion = nil
        appliedWidth = 0
        view.layer.removeAllAnimations()
        view.alpha = 1
        view.transform = .identity
    }
}
