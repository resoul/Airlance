import UIKit

extension MessageMenuView {
    var menuX: CGFloat {
        let width = Self.menuWidth

        return outgoing ? max(12, target.maxX - width) : min(target.minX, bounds.width - width - 12)
    }

    func addReceipts(_ receipts: MessageMenuReceipts, presentation: PresentationData) {
        let panel = MessageReceiptsPanel(
            receipts: receipts,
            presentation: presentation,
            backTitle: presentation.strings.chatReceiptsBack
        )
        panel.frame = collapsedReceiptsFrame
        panel.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        panel.onToggle = { [weak self] expanded in
            self?.setReceiptsExpanded(expanded)
        }
        addSubview(panel)
        receiptsPanel = panel
    }

    private var collapsedReceiptsFrame: CGRect {
        CGRect(x: menuX, y: target.maxY + 8, width: Self.menuWidth, height: MessageReceiptsPanel.summaryHeight)
    }

    private func setReceiptsExpanded(_ expanded: Bool) {
        guard let panel = receiptsPanel else {
            return
        }

        var frame = collapsedReceiptsFrame
        if expanded {
            let bottom = bounds.height - safeAreaInsets.bottom - 12
            frame.size.height = panel.expandedHeight(limit: max(menu.frame.maxY, bottom) - frame.minY)
        }
        menu.isUserInteractionEnabled = !expanded
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            panel.frame = frame
            panel.setExpanded(expanded)
            panel.layoutIfNeeded()
            self.menu.alpha = expanded ? 0 : 1
            self.menu.transform = expanded ? CGAffineTransform(translationX: 0, y: 20) : .identity
        }
    }
}
