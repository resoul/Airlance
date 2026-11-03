@preconcurrency import AsyncDisplayKit
import AvatarUI
import LiquidUI
import UIKit

@MainActor
final class StoryStripEntry {
    let container = UIView()
    let avatar = AvatarNode()
    let name = UILabel()
    let seenRing = CALayer()
    var spring = Spring(0, stiffness: 16, dampingRatio: 0.62)
    private(set) var peer: StoryPeer

    init(peer: StoryPeer, index: Int) {
        self.peer = peer
        spring.stiffness = 16 - CGFloat(min(index, 6)) * 1.2
        container.isUserInteractionEnabled = false
        seenRing.borderWidth = 1.33
        container.layer.addSublayer(seenRing)
        container.addSubview(avatar.view)
        name.textAlignment = .center
        name.isUserInteractionEnabled = false
        update(peer)
    }

    func update(_ peer: StoryPeer) {
        self.peer = peer
        avatar.apply(peer.avatar, presentation: .still)
        name.text = peer.title
    }

    func apply(_ theme: StoriesHeaderTheme, traits: UITraitCollection) {
        avatar.borderColor = theme.background.resolvedColor(with: traits).cgColor
        seenRing.borderColor = theme.seen.resolvedColor(with: traits).cgColor
        name.font = theme.nameFont
        name.textColor = theme.name
    }

    func place(center: CGPoint, size: CGFloat, openness: CGFloat, alpha: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        container.center = center
        container.alpha = alpha
        avatar.frame = container.bounds
        avatar.cornerRadius = size / 2
        avatar.borderWidth = 1.5 + 0.5 * min(openness, 1)

        let ring = size / 2 + 2.5
        seenRing.frame = CGRect(x: size / 2 - ring, y: size / 2 - ring, width: ring * 2, height: ring * 2)
        seenRing.cornerRadius = ring
        seenRing.isHidden = peer.hasUnseen
        CATransaction.commit()
    }
}
