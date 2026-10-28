@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
open class ListItemNode: ASDisplayNode {
    public internal(set) var itemID: String?

    var appliedVersion: Int?
    var appliedWidth: CGFloat = 0
    var reuseIdentifier = ""
    var layoutGeneration = 0
    var preparedLayoutVersion: Int?
    var preparedWidth: CGFloat = 0

    override open func didLoad() {
        super.didLoad()
        view.clipsToBounds = true
    }

    open func prepareForReuse() {
        itemID = nil
        layoutGeneration += 1
        preparedLayoutVersion = nil
        preparedWidth = 0
        appliedVersion = nil
        appliedWidth = 0
        view.layer.removeAllAnimations()
        view.alpha = 1
        view.transform = .identity
    }
}
