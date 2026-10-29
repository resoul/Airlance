@preconcurrency import AsyncDisplayKit
import AvatarUI
import UIKit

final class AvatarHostView: UIView {
    private let node = AvatarNode()

    init(_ descriptor: AvatarDescriptor) {
        super.init(frame: .zero)
        node.apply(descriptor)
        addSubnode(node)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        node.frame = bounds
    }
}
