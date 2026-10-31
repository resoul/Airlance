@preconcurrency import AsyncDisplayKit
import UIKit

struct SelectableText {
    let text: String
    let attributed: NSAttributedString
    let frame: CGRect
}

extension MessageBubbleNode {
    func selectableText(_ text: String) -> SelectableText? {
        guard !text.isEmpty, let layout = textLayout, let attributed = layout.node.attributedText else {
            return nil
        }

        let length = min((text as NSString).length, attributed.length)
        let frame = layout.node.frame.offsetBy(dx: layout.origin.x, dy: layout.origin.y)

        return SelectableText(
            text: text,
            attributed: attributed.attributedSubstring(from: NSRange(location: 0, length: length)),
            frame: frame
        )
    }

    func flashText(_ range: NSRange, color: UIColor) -> Bool {
        guard let layout = textLayout, range.length > 0 else {
            return false
        }

        let node = layout.node
        let origin = CGPoint(x: node.frame.minX + layout.origin.x, y: node.frame.minY + layout.origin.y)
        let rects = node.rects(forTextRange: range).map { value in
            value.cgRectValue.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -2, dy: -1)
        }
        guard !rects.isEmpty else {
            return false
        }

        let resolved = color.resolvedColor(with: view.traitCollection).cgColor
        for rect in rects {
            let highlight = CALayer()
            highlight.frame = rect
            highlight.cornerRadius = 4
            highlight.backgroundColor = resolved
            highlight.opacity = 0
            layer.addSublayer(highlight)
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [0, 1, 1, 0]
            animation.keyTimes = [0, 0.12, 0.75, 1]
            animation.duration = 1.6
            highlight.add(animation, forKey: "flash")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                highlight.removeFromSuperlayer()
            }
        }

        return true
    }
}

extension MessageBubbleNode {
    func popReaction(_ emoji: String) -> Bool {
        guard let origin = textLayoutOrigin, let frame = reactionFrame(emoji) else {
            return false
        }

        let chip = frame.offsetBy(dx: origin.x, dy: origin.y)
        let label = UILabel()
        label.text = emoji
        label.font = .systemFont(ofSize: 15)
        label.sizeToFit()
        label.center = CGPoint(x: chip.minX + 8 + label.bounds.width / 2, y: chip.midY)
        label.transform = CGAffineTransform(scaleX: 2.6, y: 2.6)
        label.alpha = 0
        view.addSubview(label)
        UIView.animate(withDuration: 0.12) {
            label.alpha = 1
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
            label.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.15) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }

        return true
    }
}
