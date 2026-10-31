import QuartzCore
import UIKit

@MainActor
final class TabBarTransitionFollower: NSObject {
    private weak var bar: UIView?
    private weak var cover: UIView?
    private weak var base: UIView?
    private weak var space: UIView?
    private let mask = CALayer()
    private var link: CADisplayLink?

    init(bar: UIView, cover: UIView, base: UIView, space: UIView) {
        self.bar = bar
        self.cover = cover
        self.base = base
        self.space = space
        super.init()
        mask.backgroundColor = UIColor.black.cgColor
    }

    func start() {
        bar?.layer.mask = mask
        bar?.alpha = 1
        bar?.isUserInteractionEnabled = false
        step()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        bar?.layer.mask = nil
    }

    @objc
    private func step() {
        guard let bar, let cover, let base, let space else {
            return
        }

        let coverX = frame(of: cover, in: space).minX
        let baseX = frame(of: base, in: space).minX
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.transform = CGAffineTransform(translationX: baseX, y: 0)
        mask.frame = CGRect(x: 0, y: 0, width: max(0, coverX - baseX), height: bar.bounds.height)
        CATransaction.commit()
    }

    private func frame(of view: UIView, in space: UIView) -> CGRect {
        let layer = view.layer.presentation() ?? view.layer
        guard let container = view.superview else {
            return layer.frame
        }

        return container.convert(layer.frame, to: space)
    }
}
