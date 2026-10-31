@preconcurrency import AsyncDisplayKit
import EffectsUI
import UIKit

extension MessageBubbleNode {
    func applySpoilers(_ ranges: [NSRange], revealed: Bool, ink: UIColor, onRevealed: (@MainActor () -> Void)?) {
        onSpoilerRevealed = onRevealed
        guard !ranges.isEmpty, !revealed, let layout = textLayout, isNodeLoaded else {
            if spoilerView?.isRevealing != true {
                removeSpoiler()
            }

            return
        }

        let text = layout.node
        let frame = text.frame.offsetBy(dx: layout.origin.x, dy: layout.origin.y).insetBy(dx: -8, dy: -6)
        let rects = ranges.flatMap { range in
            text.rects(forTextRange: range).map { value in
                value.cgRectValue.offsetBy(dx: 8, dy: 6)
            }
        }
        let spoiler = spoilerView ?? InkSpoilerView(frame: frame, scale: view.traitCollection.displayScale)
        guard let spoiler else {
            return
        }

        spoiler.frame = frame
        spoiler.inkColor = ink
        spoiler.onRevealed = { [weak self, weak spoiler] in
            spoiler?.removeFromSuperview()
            if self?.spoilerView === spoiler {
                self?.spoilerView = nil
            }
            self?.onSpoilerRevealed?()
        }
        spoiler.setRects(rects)
        if spoiler.superview !== view {
            view.addSubview(spoiler)
        }
        spoilerView = spoiler
    }

    func revealSpoiler(at point: CGPoint) -> Bool {
        guard let spoiler = spoilerView, !spoiler.isRevealing else {
            return false
        }

        let local = view.convert(point, to: spoiler)
        guard spoiler.covers(local) else {
            return false
        }

        spoiler.reveal(from: local)

        return true
    }

    func removeSpoiler() {
        spoilerView?.removeFromSuperview()
        spoilerView = nil
    }
}
