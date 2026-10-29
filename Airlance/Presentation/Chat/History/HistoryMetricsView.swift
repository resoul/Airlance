import Haptics
import UIKit

final class HistoryMetricsView: UIView {
    var onCopy: (@MainActor (String) -> Void)?

    private let metrics: HistoryMetrics
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let label = UILabel()
    private var isRefreshScheduled = false

    init(metrics: HistoryMetrics) {
        self.metrics = metrics
        super.init(frame: .zero)
        layer.cornerRadius = 10
        clipsToBounds = true
        addSubview(blur)
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        addSubview(label)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copySummary)))
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(reset(_:))))
        metrics.onChange = { [weak self] in
            self?.scheduleRefresh()
        }
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let text = label.sizeThatFits(CGSize(width: size.width - 16, height: .greatestFiniteMagnitude))

        return CGSize(width: min(size.width, ceil(text.width) + 16), height: ceil(text.height) + 12)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        label.frame = bounds.insetBy(dx: 8, dy: 6)
    }

    func place(at origin: CGPoint, maxWidth: CGFloat) {
        frame = CGRect(origin: origin, size: sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude)))
    }

    private func scheduleRefresh() {
        guard !isRefreshScheduled else {
            return
        }

        isRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isRefreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        guard window != nil else {
            return
        }

        label.text = metrics.summary
        place(at: frame.origin, maxWidth: superview?.bounds.width ?? 320)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }

    @objc
    private func copySummary() {
        UIPasteboard.general.string = metrics.summary
        Haptics.play(.success)
        onCopy?(metrics.summary)
    }

    @objc
    private func reset(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else {
            return
        }

        metrics.reset()
        Haptics.play(.warning)
    }
}
