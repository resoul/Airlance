import Haptics
import Theme
import UIKit

public struct PopupMenuItem {
    public let title: String
    public let symbol: String?
    public let image: UIImage?
    public let isChecked: Bool
    public let isDestructive: Bool
    public let handler: @MainActor () -> Void

    public init(title: String, symbol: String, isDestructive: Bool = false, handler: @escaping @MainActor () -> Void) {
        self.title = title
        self.symbol = symbol
        image = nil
        isChecked = false
        self.isDestructive = isDestructive
        self.handler = handler
    }

    public init(title: String, image: UIImage, isChecked: Bool, handler: @escaping @MainActor () -> Void) {
        self.title = title
        symbol = nil
        self.image = image
        self.isChecked = isChecked
        isDestructive = false
        self.handler = handler
    }
}

@MainActor
public final class PopupMenu: UIView, FocusOverlay {
    static let rowHeight: CGFloat = 46
    private static let width: CGFloat = 240
    private static let margin: CGFloat = 16

    let panel = UIView()
    let items: [PopupMenuItem]
    let headerHeight: CGFloat
    var highlights: [UIView] = []
    var highlighted: Int?
    var gate = MenuGestureGate()
    private let blur = UIVisualEffectView(effect: nil)
    private var isClosing = false

    private init(items: [PopupMenuItem], header: String?, theme: AppTheme, frame: CGRect) {
        self.items = items
        let headerLabel = header.map { text in
            Self.headerLabel(text, theme: theme)
        }
        headerHeight = headerLabel.map { label in
            label.frame.maxY + 10
        } ?? 0
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
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0
        panel.addGestureRecognizer(press)
        if let headerLabel {
            panel.addSubview(headerLabel)
            addLine(at: headerHeight, theme: theme)
        }
        for (index, item) in items.enumerated() {
            let highlight = UIView(frame: rowFrame(index))
            highlight.backgroundColor = theme.colors.textPrimary.withAlphaComponent(0.08)
            highlight.alpha = 0
            highlights.append(highlight)
            panel.addSubview(highlight)
            panel.addSubview(row(for: item, theme: theme, index: index))
            if index < items.count - 1 {
                addLine(at: rowFrame(index).maxY, theme: theme)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @discardableResult
    public static func show(
        _ items: [PopupMenuItem],
        theme: AppTheme,
        from anchor: CGRect,
        in container: UIView,
        below sibling: UIView? = nil,
        header: String? = nil
    ) -> PopupMenu? {
        guard !items.isEmpty else {
            return nil
        }

        let menu = PopupMenu(items: items, header: header, theme: theme, frame: container.bounds)
        menu.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let sibling, sibling.superview === container {
            container.insertSubview(menu, belowSubview: sibling)
        } else {
            container.addSubview(menu)
        }
        menu.present(count: items.count, anchor: anchor)

        return menu
    }

    private func present(count: Int, anchor: CGRect) {
        let height = headerHeight + CGFloat(count) * Self.rowHeight
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
        } completion: { _ in
            self.gate.isReady = true
        }
    }

    private func row(for item: PopupMenuItem, theme: AppTheme, index: Int) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = item.title
        let symbol = item.symbol.flatMap(UIImage.init(systemName:))
        configuration.image = item.image?.withRenderingMode(.alwaysOriginal) ?? symbol
        configuration.imagePlacement = item.image == nil ? .trailing : .leading
        configuration.imagePadding = 12
        configuration.baseForegroundColor = item.isDestructive ? theme.colors.destructive : theme.colors.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = theme.fonts.body

            return attributes
        }
        let row = UIButton(configuration: configuration)
        row.frame = rowFrame(index)
        row.contentHorizontalAlignment = item.image == nil ? .fill : .leading
        if item.isChecked {
            addCheckmark(to: row, color: theme.colors.accent)
        }
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

    private func addCheckmark(to row: UIButton, color: UIColor) {
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = color
        checkmark.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        checkmark.sizeToFit()
        checkmark.center = CGPoint(x: row.bounds.width - 16 - checkmark.bounds.width / 2, y: row.bounds.midY)
        checkmark.isUserInteractionEnabled = false
        row.addSubview(checkmark)
    }

    private func rowFrame(_ index: Int) -> CGRect {
        CGRect(x: 0, y: headerHeight + CGFloat(index) * Self.rowHeight, width: Self.width, height: Self.rowHeight)
    }

    private func addLine(at y: CGFloat, theme: AppTheme) {
        let line = UIView(frame: CGRect(x: 0, y: y - 0.5, width: Self.width, height: 0.5))
        line.backgroundColor = theme.colors.separator
        panel.addSubview(line)
    }

    private static func headerLabel(_ text: String, theme: AppTheme) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = theme.fonts.caption
        label.textColor = theme.colors.textSecondary
        label.numberOfLines = 3
        label.lineBreakMode = .byTruncatingMiddle
        let width = Self.width - 32
        let height = ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        label.frame = CGRect(x: 16, y: 10, width: width, height: height)

        return label
    }

    @objc
    private func dismissTapped() {
        close(nil)
    }

    func close(_ completion: (@MainActor () -> Void)?) {
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
