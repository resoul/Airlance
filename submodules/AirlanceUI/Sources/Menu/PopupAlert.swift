import Haptics
import Theme
import UIKit

public struct PopupAlertAction {
    public enum Style {
        case normal
        case cancel
        case destructive
    }

    public let title: String
    public let style: Style
    public let handler: (@MainActor () -> Void)?

    public init(title: String, style: Style = .normal, handler: (@MainActor () -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

@MainActor
public final class PopupAlert: UIView, FocusOverlay {
    private static let width: CGFloat = 280
    private static let rowHeight: CGFloat = 46
    private static let padding: CGFloat = 20

    private let blur = UIVisualEffectView(effect: nil)
    private let card = UIView()
    private let cancel: PopupAlertAction?
    private var isClosing = false

    private init(
        header: UIView?,
        title: String?,
        message: String?,
        actions: [PopupAlertAction],
        theme: AppTheme,
        frame: CGRect
    ) {
        cancel = actions.first { action in
            action.style == .cancel
        }
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(outsideTapped)))
        addSubview(blur)

        card.backgroundColor = theme.colors.surface
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        addSubview(card)
        let headerHeight = addHeader(header)
        let textHeight = addText(title: title, message: message, theme: theme, top: headerHeight)
        let ordered = actions.filter { action in
            action.style != .cancel
        } + actions.filter { action in
            action.style == .cancel
        }
        for (index, action) in ordered.enumerated() {
            let y = textHeight + CGFloat(index) * Self.rowHeight
            addSeparator(at: y, theme: theme)
            card.addSubview(button(for: action, theme: theme, y: y))
        }
        let height = textHeight + CGFloat(ordered.count) * Self.rowHeight
        card.bounds = CGRect(x: 0, y: 0, width: Self.width, height: height)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public static func show(
        header: UIView? = nil,
        title: String?,
        message: String?,
        actions: [PopupAlertAction],
        theme: AppTheme,
        in view: UIView
    ) {
        let container: UIView = view.window ?? view
        let alert = PopupAlert(
            header: header,
            title: title,
            message: message,
            actions: actions,
            theme: theme,
            frame: container.bounds
        )
        container.addSubview(alert)
        alert.present()
    }

    private func present() {
        card.center = CGPoint(x: bounds.midX, y: bounds.midY)
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        Haptics.play(.popup)
        UIView.animate(withDuration: 0.3) {
            self.blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.card.alpha = 1
            self.card.transform = .identity
        }
    }

    private func addHeader(_ header: UIView?) -> CGFloat {
        guard let header else {
            return 0
        }

        header.frame.origin = CGPoint(x: (Self.width - header.bounds.width) / 2, y: Self.padding)
        card.addSubview(header)

        return header.frame.maxY
    }

    private func addText(title: String?, message: String?, theme: AppTheme, top: CGFloat) -> CGFloat {
        guard title != nil || message != nil else {
            return top > 0 ? top + Self.padding : 0
        }

        var y = top + (top > 0 ? 12 : Self.padding)
        let width = Self.width - Self.padding * 2
        for (text, isTitle) in [(title, true), (message, false)] {
            guard let text else {
                continue
            }

            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = isTitle ? theme.fonts.headline : theme.fonts.subheadline
            label.textColor = isTitle ? theme.colors.textPrimary : theme.colors.textSecondary
            let height = ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            label.frame = CGRect(x: Self.padding, y: y, width: width, height: height)
            card.addSubview(label)
            y += height + 6
        }

        return y - 6 + Self.padding
    }

    private func addSeparator(at y: CGFloat, theme: AppTheme) {
        guard y > 0 else {
            return
        }

        let line = UIView(frame: CGRect(x: 0, y: y - 0.25, width: Self.width, height: 0.5))
        line.backgroundColor = theme.colors.separator
        card.addSubview(line)
    }

    private func button(for action: PopupAlertAction, theme: AppTheme, y: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: y, width: Self.width, height: Self.rowHeight)
        button.setTitle(action.title, for: .normal)
        switch action.style {
        case .normal:
            button.setTitleColor(theme.colors.accent, for: .normal)
            button.titleLabel?.font = theme.fonts.body
        case .cancel:
            button.setTitleColor(theme.colors.accent, for: .normal)
            button.titleLabel?.font = theme.fonts.headline
        case .destructive:
            button.setTitleColor(theme.colors.destructive, for: .normal)
            button.titleLabel?.font = theme.fonts.body
        }
        let handler = action.handler
        button.addAction(
            UIAction { [weak self] _ in
                self?.close(handler)
            },
            for: .touchUpInside
        )

        return button
    }

    @objc
    private func outsideTapped() {
        guard let cancel else {
            return
        }

        close(cancel.handler)
    }

    private func close(_ completion: (@MainActor () -> Void)?) {
        guard !isClosing else {
            return
        }

        isClosing = true
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.blur.effect = nil
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
