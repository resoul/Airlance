import Haptics
import UIKit

final class MessageMenuView: UIView {
    private static let menuWidth: CGFloat = 250

    private let blur = UIVisualEffectView(effect: nil)
    private let lifted: UIView
    private let source: CGRect
    private var target: CGRect
    private let menu: MenuListView
    private let outgoing: Bool

    init(
        bubble: UIView,
        frame bubbleFrame: CGRect,
        outgoing: Bool,
        items: [MenuItem],
        presentation: PresentationData,
        host: UIView
    ) {
        source = bubble.convert(bubbleFrame, to: host)
        let snapshot = bubble.resizableSnapshotView(from: bubbleFrame, afterScreenUpdates: false, withCapInsets: .zero)
        lifted = snapshot ?? UIView()
        target = source
        self.outgoing = outgoing
        menu = MenuListView(presentation: presentation)
        super.init(frame: host.bounds)
        host.addSubview(self)
        blur.frame = bounds
        blur.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        addSubview(blur)

        let menuHeight = MenuListView.rowHeight * CGFloat(items.count)
        let top = host.safeAreaInsets.top + 12
        let bottom = host.bounds.height - host.safeAreaInsets.bottom - 12 - menuHeight - 8
        target.size.height = min(source.height, max(0, bottom - top))
        target.origin.y = min(max(source.minY, top), bottom - target.height)
        lifted.frame = source
        lifted.clipsToBounds = true
        addSubview(lifted)
        menu.onPerform = { [weak self] item in
            self?.perform(item)
        }
        addSubview(menu)
        show(items)
        menu.alpha = 0
        menu.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        Haptics.play(.menu)
        UIView.animate(withDuration: 0.3) {
            self.blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.lifted.frame = self.target
            self.lifted.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        }
        UIView.animate(withDuration: 0.45, delay: 0.05, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.menu.alpha = 1
            self.menu.transform = .identity
        }
    }

    func track(_ point: CGPoint, ended: Bool) {
        guard isUserInteractionEnabled else {
            return
        }

        menu.track(convert(point, to: menu), ended: ended)
    }

    private func show(_ items: [MenuItem]) {
        menu.setItems(items)
        let width = Self.menuWidth
        let height = menu.contentHeight
        let x = outgoing ? max(12, target.maxX - width) : min(target.minX, bounds.width - width - 12)
        menu.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        menu.center = CGPoint(x: x + width / 2, y: target.maxY + 8 + height / 2)
        menu.layoutIfNeeded()
    }

    private func perform(_ item: MenuItem) {
        switch item.action {
        case .run(let handler):
            close {
                handler()
            }
        case .submenu(let items):
            Haptics.play(.tap)
            UIView.transition(with: menu, duration: 0.22, options: .transitionCrossDissolve) {
                self.show(items)
            }
        }
    }

    @objc
    private func dismiss() {
        close(nil)
    }

    private func close(_ completion: (@MainActor () -> Void)?) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.menu.alpha = 0
            self.menu.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.lifted.transform = .identity
            self.lifted.frame = self.source
            self.blur.effect = nil
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
