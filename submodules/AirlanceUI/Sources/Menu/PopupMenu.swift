import Haptics
import Theme
import UIKit

public struct PopupMenuItem {
    public let title: String
    public let symbol: String
    public let isDestructive: Bool
    public let handler: @MainActor () -> Void

    public init(title: String, symbol: String, isDestructive: Bool = false, handler: @escaping @MainActor () -> Void) {
        self.title = title
        self.symbol = symbol
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

@MainActor
public final class PopupMenu: UIView {
    private static let width: CGFloat = 240
    private static let rowHeight: CGFloat = 46
    private static let margin: CGFloat = 16

    private let blur = UIVisualEffectView(effect: nil)
    private let panel = UIView()
    private var isClosing = false

    private init(items: [PopupMenuItem], theme: AppTheme, frame: CGRect) {
        super.init(frame: frame)
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        addSubview(blur)

        panel.backgroundColor = theme.colors.surface
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        panel.clipsToBounds = true
        addSubview(panel)
        for (index, item) in items.enumerated() {
            panel.addSubview(row(for: item, theme: theme, index: index))
            if index < items.count - 1 {
                let line = UIView(frame: CGRect(
                    x: 0,
                    y: CGFloat(index + 1) * Self.rowHeight - 0.5,
                    width: Self.width,
                    height: 0.5
                ))
                line.backgroundColor = theme.colors.separator
                panel.addSubview(line)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public static func show(
        _ items: [PopupMenuItem],
        theme: AppTheme,
        from anchor: CGRect,
        in container: UIView,
        below sibling: UIView? = nil
    ) {
        guard !items.isEmpty else {
            return
        }

        let menu = PopupMenu(items: items, theme: theme, frame: container.bounds)
        menu.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let sibling, sibling.superview === container {
            container.insertSubview(menu, belowSubview: sibling)
        } else {
            container.addSubview(menu)
        }
        menu.present(count: items.count, anchor: anchor)
    }

    private func present(count: Int, anchor: CGRect) {
        let height = CGFloat(count) * Self.rowHeight
        let x = min(max(anchor.midX - Self.width / 2, Self.margin), bounds.width - Self.width - Self.margin)
        let below = anchor.minY - 10 - height < safeAreaInsets.top + Self.margin
        let y = below ? anchor.maxY + 10 : anchor.minY - 10 - height
        let pivotX = min(max((anchor.midX - x) / Self.width, 0), 1)
        panel.layer.anchorPoint = CGPoint(x: pivotX, y: below ? 0 : 1)
        panel.bounds = CGRect(x: 0, y: 0, width: Self.width, height: height)
        panel.center = CGPoint(x: x + Self.width * pivotX, y: below ? y : y + height)
        panel.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)

        Haptics.play(.menu)
        UIView.animate(withDuration: 0.3) {
            self.blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.panel.alpha = 1
            self.panel.transform = .identity
        }
    }

    private func row(for item: PopupMenuItem, theme: AppTheme, index: Int) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = item.title
        configuration.image = UIImage(systemName: item.symbol)
        configuration.imagePlacement = .trailing
        configuration.baseForegroundColor = item.isDestructive ? theme.colors.destructive : theme.colors.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = theme.fonts.body

            return attributes
        }
        let row = UIButton(configuration: configuration)
        row.frame = CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: Self.width, height: Self.rowHeight)
        row.contentHorizontalAlignment = .fill
        let handler = item.handler
        row.addAction(
            UIAction { [weak self] _ in
                self?.close {
                    handler()
                }
            },
            for: .touchUpInside
        )

        return row
    }

    @objc
    private func dismissTapped() {
        close(nil)
    }

    private func close(_ completion: (@MainActor () -> Void)?) {
        guard !isClosing else {
            return
        }

        isClosing = true
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.panel.alpha = 0
            self.panel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.blur.effect = nil
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
