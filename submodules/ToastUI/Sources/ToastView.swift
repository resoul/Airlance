import Haptics
import Theme
import UIKit

@MainActor
final class ToastView: UIView {
    static let minimumVisibleTime: TimeInterval = 1
    static let margin: CGFloat = 8

    let toast: Toast
    var onFinish: (@MainActor () -> Void)?

    let pan = UIPanGestureRecognizer()
    var drag = CGPoint.zero
    var isHeld = false
    private(set) var isClosing = false
    private let icon = UIImageView()
    private let label = UILabel()
    private var timer: Task<Void, Never>?
    private var shownAt: Date?
    private var isHurried = false

    var isActive: Bool {
        !isClosing
    }

    var reducesMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    init(toast: Toast, theme: AppTheme) {
        self.toast = toast
        super.init(frame: .zero)
        backgroundColor = theme.colors.surface
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        icon.image = toast.symbol.flatMap { symbol in
            UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        }
        icon.tintColor = Self.tint(for: toast.style, theme: theme)
        icon.contentMode = .center
        icon.isHidden = toast.symbol == nil
        addSubview(icon)

        label.text = toast.text
        label.font = theme.fonts.subheadline
        label.textColor = theme.colors.textPrimary
        label.numberOfLines = 2
        addSubview(label)

        isAccessibilityElement = true
        accessibilityLabel = toast.text
        accessibilityTraits = toast.action == nil ? .staticText : .button
        installGestures()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func place(in container: CGRect, safeArea: UIEdgeInsets) {
        let leading: CGFloat = toast.symbol == nil ? 18 : 46
        let maxWidth = min(container.width - 32, 420)
        let text = label.sizeThatFits(CGSize(width: maxWidth - leading - 18, height: .greatestFiniteMagnitude))
        let size = CGSize(width: ceil(leading + text.width + 18), height: max(44, ceil(text.height) + 24))
        let y: CGFloat
        switch toast.edge {
        case .top:
            y = safeArea.top + Self.margin + toast.inset + size.height / 2
        case .bottom:
            y = container.height - safeArea.bottom - Self.margin - toast.inset - size.height / 2
        }
        bounds = CGRect(origin: .zero, size: size)
        center = CGPoint(x: container.midX, y: y)
        layer.cornerRadius = min(22, size.height / 2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        icon.frame = CGRect(x: 12, y: 0, width: 28, height: size.height)
        label.frame = CGRect(x: leading, y: (size.height - text.height) / 2, width: text.width, height: text.height)
    }

    func present(hurried: Bool) {
        isHurried = hurried
        switch toast.style {
        case .info:
            break
        case .success:
            Haptics.play(.success)
        case .error:
            Haptics.play(.error)
        }
        UIAccessibility.post(notification: .announcement, argument: toast.text)
        if reducesMotion {
            alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1
            }
        } else {
            transform = hiddenTransform
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
                self.transform = .identity
            }
        }
        shownAt = Date()
        scheduleDismissal()
    }

    func repeatToast() {
        pop()
        scheduleDismissal()
    }

    func hurry() {
        isHurried = true
        scheduleDismissal()
    }

    func scheduleDismissal() {
        timer?.cancel()
        guard !isClosing, !isHeld else {
            return
        }

        let elapsed = shownAt.map { date in
            Date().timeIntervalSince(date)
        } ?? 0
        let delay = isHurried ? max(0, Self.minimumVisibleTime - elapsed) : toast.duration
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }

            self?.dismiss()
        }
    }

    func pauseDismissal() {
        timer?.cancel()
        timer = nil
    }

    func dismiss(velocity: CGFloat = 0) {
        guard !isClosing else {
            return
        }

        isClosing = true
        timer?.cancel()
        isUserInteractionEnabled = false
        let finish = { [weak self] in
            self?.removeFromSuperview()
            self?.onFinish?()
        }
        if reducesMotion {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }, completion: { _ in
                finish()
            })

            return
        }

        let distance = abs(hiddenTransform.ty - transform.ty)
        let speed = distance > 0 ? abs(velocity) / distance : 0
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: speed,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.transform = self.hiddenTransform
        } completion: { _ in
            finish()
        }
    }

    private var hiddenTransform: CGAffineTransform {
        let height = superview?.bounds.height ?? 0
        let offset: CGFloat
        switch toast.edge {
        case .top:
            offset = -(center.y + bounds.height / 2 + 12)
        case .bottom:
            offset = height - center.y + bounds.height / 2 + 12
        }

        return CGAffineTransform(translationX: 0, y: offset).scaledBy(x: 0.8, y: 0.8)
    }

    private func pop() {
        guard !reducesMotion, drag == .zero else {
            return
        }

        transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6) {
            self.transform = .identity
        }
    }

    private static func tint(for style: Toast.Style, theme: AppTheme) -> UIColor {
        switch style {
        case .info:
            theme.colors.accent
        case .success:
            .systemGreen
        case .error:
            theme.colors.destructive
        }
    }
}
