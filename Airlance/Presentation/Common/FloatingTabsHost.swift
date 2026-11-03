import AirlanceUI
import Theme
import UIKit

final class FloatingTabsHost: UIView {
    static let height: CGFloat = 56
    static let capsuleHeight: CGFloat = 44

    private let card = FloatingCard()
    private let tabs: LiquidTabsView

    init(tabs: LiquidTabsView) {
        self.tabs = tabs
        super.init(frame: .zero)
        card.radius = Self.capsuleHeight / 2
        card.content.addSubview(tabs)
        card.setRows([(tabs, Self.capsuleHeight)])
        addSubview(card)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        backgroundColor = .clear
        card.apply(theme)
        tabs.background = theme.colors.surface
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        card.frame.contains(point) ? super.hitTest(point, with: event) : nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = (bounds.height - Self.capsuleHeight) / 2
        card.frame = CGRect(x: 16, y: top, width: bounds.width - 32, height: Self.capsuleHeight)
    }
}
