import Theme
import UIKit

extension ChatInputBar {
    static let controlSize: CGFloat = 44

    static func floatingGap(safeArea: CGFloat) -> CGFloat {
        max(safeArea * 0.6, 12)
    }

    func applyFloating(_ theme: AppTheme) {
        for view in [attachButton, fieldBox, actionCircle, replyPanel] as [UIView] {
            view.backgroundColor = theme.colors.surface
            view.layer.borderColor = theme.colors.separator.cgColor
            view.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.12
            view.layer.shadowRadius = 12
            view.layer.shadowOffset = CGSize(width: 0, height: 3)
            view.layer.cornerCurve = .continuous
        }
    }

    func layoutFloating() {
        let radii: [(UIView, CGFloat)] = [
            (attachButton, Self.controlSize / 2),
            (actionCircle, Self.controlSize / 2),
            (fieldBox, min(fieldBox.bounds.height / 2, 22)),
            (replyPanel, 18),
        ]
        for (view, radius) in radii {
            view.layer.cornerRadius = radius
            view.layer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: radius).cgPath
        }
    }

    func setActionFilled(_ isFilled: Bool, theme: AppTheme, animated: Bool) {
        let changes = {
            self.actionCircle.backgroundColor = isFilled ? theme.colors.accent : theme.colors.surface
            self.actionCircle.layer.borderWidth = isFilled ? 0 : 1 / max(self.traitCollection.displayScale, 1)
        }
        guard animated else {
            changes()

            return
        }

        UIView.animate(withDuration: 0.2, animations: changes)
    }
}
