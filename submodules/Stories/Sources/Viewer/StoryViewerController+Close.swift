import AvatarUI
import UIKit

extension StoryViewerController {
    private static let closeScale: CGFloat = 0.32
    private static let closeDrift: CGFloat = 0.55

    var cornerGoal: CGFloat {
        guard phase == .closing else {
            return 0
        }

        return closeWidth > 0 ? 14 : goal.width / 2
    }

    func stageAlpha(width: CGFloat, openness: CGFloat) -> CGFloat {
        if phase == .closing, closeWidth > goal.width {
            let remaining = (width - goal.width) / (closeWidth - goal.width)

            return min(max(remaining * 1.6, 0), 1)
        }

        return fadesWithSource ? min(1, openness * 3) : 1
    }

    func shrunkRect(toward source: CGRect) -> CGRect {
        let bounds = view.bounds
        let size = CGSize(width: bounds.width * Self.closeScale, height: bounds.height * Self.closeScale)
        let center = CGPoint(
            x: bounds.midX + (source.midX - bounds.midX) * Self.closeDrift,
            y: bounds.midY + (source.midY - bounds.midY) * Self.closeDrift
        )

        return CGRect(origin: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), size: size)
    }

    func setSprings(closing: Bool) {
        let stiffness: [CGFloat] = closing ? [22, 22, 22, 22, 22] : [12, 9.5, 11, 10, 10]
        let damping: [CGFloat] = closing ? [1, 1, 1, 1, 1] : [0.7, 0.66, 0.7, 0.68, 0.85]
        top.stiffness = stiffness[0]
        bottom.stiffness = stiffness[1]
        left.stiffness = stiffness[2]
        right.stiffness = stiffness[3]
        corner.stiffness = stiffness[4]
        top.dampingRatio = damping[0]
        bottom.dampingRatio = damping[1]
        left.dampingRatio = damping[2]
        right.dampingRatio = damping[3]
        corner.dampingRatio = damping[4]
    }

    func flyAvatar(of page: StoryPageView, to target: CGRect) {
        guard let window = view.window else {
            return
        }

        let start = page.avatarFrame(in: window)
        let peerID = page.author.id
        let source = transition.source
        page.setAvatarHidden(true)
        source?.setStoryAvatarHidden(true, for: peerID)
        let flyer = AvatarNode()
        flyer.apply(page.author.peer.avatar, presentation: .still)
        flyer.frame = target
        flyer.cornerRadius = target.width / 2
        let scale = start.width / max(target.width, 1)
        flyer.view.transform = CGAffineTransform(translationX: start.midX - target.midX, y: start.midY - target.midY)
            .scaledBy(x: scale, y: scale)
        window.addSubview(flyer.view)
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.74,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState]
        ) {
            flyer.view.transform = .identity
        } completion: { _ in
            source?.setStoryAvatarHidden(false, for: peerID)
            flyer.view.removeFromSuperview()
        }
    }
}
