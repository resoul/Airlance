import UIKit

enum BubbleSelection: Hashable, Sendable {
    case unselected
    case selected
}

extension MessageBubbleNode {
    static let selectionInset: CGFloat = 42

    private static let checkCenterX: CGFloat = 23

    func applySelection(_ state: BubbleSelection?, tint: UIColor, animated: Bool) {
        let previous = selectionState
        selectionState = state
        let shift: CGFloat = state != nil && !isOutgoing ? Self.selectionInset : 0
        let check = selectionCheck ?? makeCheck()
        let symbol = state == .selected ? "checkmark.circle.fill" : "circle"
        check.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
        check.tintColor = state == .selected ? tint : UIColor.secondaryLabel
        let y = bubbleFrame?.midY ?? bounds.midY
        check.center = CGPoint(x: isOutgoing ? Self.checkCenterX : Self.checkCenterX - Self.selectionInset, y: y)
        moveContent(to: shift, animated: animated)
        let visible = state != nil
        let changes = {
            check.alpha = visible ? 1 : 0
            check.transform = visible || !self.isOutgoing ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        if animated {
            let options: UIView.AnimationOptions = [.curveEaseInOut, .beginFromCurrentState]
            UIView.animate(withDuration: 0.3, delay: 0, options: options, animations: changes)
        } else {
            changes()
        }
        if animated, previous == .unselected, state == .selected {
            check.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
                check.transform = .identity
            }
        }
    }

    private func makeCheck() -> UIImageView {
        let check = UIImageView(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
        check.contentMode = .center
        check.alpha = 0
        check.isUserInteractionEnabled = false
        view.addSubview(check)
        selectionCheck = check

        return check
    }

    private func moveContent(to shift: CGFloat, animated: Bool) {
        let target = CATransform3DMakeTranslation(shift, 0, 0)
        guard !CATransform3DEqualToTransform(layer.sublayerTransform, target) else {
            return
        }

        if animated {
            let animation = CABasicAnimation(keyPath: "sublayerTransform")
            animation.fromValue = layer.presentation()?.sublayerTransform ?? layer.sublayerTransform
            animation.toValue = target
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "selectionShift")
        }
        layer.sublayerTransform = target
    }
}
