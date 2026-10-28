import Theme
import UIKit

@MainActor
final class ToastHostView: UIView {
    private static let queueLimit = 3

    private var queue: [Toast] = []
    private var current: ToastView?
    private var theme: AppTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func enqueue(_ toast: Toast, theme: AppTheme) {
        self.theme = theme
        if let current, current.isActive, current.toast.key == toast.key {
            current.repeatToast()

            return
        }

        guard !queue.contains(where: { queued in
            queued.key == toast.key
        }) else {
            return
        }

        queue.append(toast)
        if queue.count > Self.queueLimit {
            queue.removeFirst(queue.count - Self.queueLimit)
        }
        if let current {
            current.hurry()
        } else {
            showNext()
        }
    }

    func dismissAll() {
        queue.removeAll()
        current?.dismiss()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let current, current.isActive else {
            return false
        }

        return current.frame.insetBy(dx: -6, dy: -6).contains(point)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        current?.place(in: bounds, safeArea: safeAreaInsets)
    }

    private func showNext() {
        guard current == nil else {
            return
        }

        guard !queue.isEmpty, let theme else {
            removeFromSuperview()

            return
        }

        let view = ToastView(toast: queue.removeFirst(), theme: theme)
        view.onFinish = { [weak self, weak view] in
            guard let self, self.current === view else {
                return
            }

            self.current = nil
            self.showNext()
        }
        current = view
        addSubview(view)
        view.place(in: bounds, safeArea: safeAreaInsets)
        view.present(hurried: !queue.isEmpty)
    }
}
