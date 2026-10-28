@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class CollapsingContainer: ASDisplayNode {
    public let header: UIView
    public let pager: PanePager
    public let coordinator: VerticalScrollCoordinator
    public var onChange: (@MainActor () -> Void)?

    public var pinnedTopInset: CGFloat = 0 {
        didSet {
            if pinnedTopInset != oldValue {
                setNeedsLayout()
            }
        }
    }

    private let pan = UIPanGestureRecognizer()
    private let panGate = PanGestureDelegate()
    private weak var activePane: (any ScrollablePane)?
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var previousTranslation: CGFloat = 0
    private var velocity: CGFloat = 0
    private var isSuspended = false

    public var isDragging: Bool {
        pan.state == .began || pan.state == .changed
    }

    public init(header: UIView, pager: PanePager) {
        self.header = header
        self.pager = pager
        coordinator = VerticalScrollCoordinator(headerHeight: 0)
        super.init()
        addSubnode(pager)
        coordinator.onChange = { [weak self] in
            self?.placeContent()
        }
        pager.onPaneChange = { [weak self] pane in
            self?.activate(pane)
        }
        pager.onPagingBegan = { [weak self] in
            self?.stopMotion()
        }
    }

    override public func didLoad() {
        super.didLoad()
        view.clipsToBounds = true
        view.addSubview(header)
        pan.maximumNumberOfTouches = 1
        panGate.shouldBegin = { [weak self] pan in
            self?.shouldBeginScrolling(pan) ?? false
        }
        panGate.shouldReceive = { [weak self] in
            self?.stopMotion()
        }
        pan.delegate = panGate
        pan.addTarget(self, action: #selector(panned(_:)))
        view.addGestureRecognizer(pan)
        activate(pager.currentPane)
    }

    override public func layout() {
        super.layout()
        coordinator.viewportHeight = max(0, bounds.height - pinnedTopInset)
        placeContent()
        coordinator.reconcile()
    }

    public func setHeaderHeight(_ height: CGFloat) {
        coordinator.setHeaderHeight(height, preservingContentPosition: true)
    }

    public func scrollToTop() {
        stopMotion()
        coordinator.scrollToTop()
    }

    public func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        if suspended {
            stopMotion()
        }
    }

    public func stopMotion() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
        velocity = 0
        coordinator.finishBounce()
    }

    override public func didExitHierarchy() {
        super.didExitHierarchy()
        stopMotion()
    }

    private func activate(_ pane: (any ScrollablePane)?) {
        if let pane, let activePane, pane === activePane {
            coordinator.reconcile()

            return
        }

        stopMotion()
        activePane?.onGeometryChange = nil
        activePane = pane
        pane?.onGeometryChange = { [weak self] in
            self?.coordinator.reconcile()
        }
        coordinator.activate(pane)
    }

    private func placeContent() {
        if coordinator.isHeaderVisible {
            pager.resetOffsets(except: activePane)
        }
        let top = coordinator.topStretch - coordinator.headerOffset
        header.frame = CGRect(
            x: 0,
            y: top,
            width: bounds.width,
            height: coordinator.headerHeight + pinnedTopInset
        )
        pager.frame = CGRect(
            x: 0,
            y: top + pinnedTopInset + coordinator.headerHeight,
            width: bounds.width,
            height: max(0, bounds.height - pinnedTopInset)
        )
        onChange?()
    }
}

extension CollapsingContainer {
    private func shouldBeginScrolling(_ pan: UIPanGestureRecognizer) -> Bool {
        guard !isSuspended, !pager.isPaging else {
            return false
        }

        let movement = pan.velocity(in: view)

        return abs(movement.y) > abs(movement.x)
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view).y
        switch gesture.state {
        case .began:
            stopMotion()
            previousTranslation = translation
            coordinator.consume(-translation)
        case .changed:
            coordinator.consume(previousTranslation - translation)
            previousTranslation = translation
        case .ended:
            coordinator.consume(previousTranslation - translation)
            startMotion(velocity: -gesture.velocity(in: view).y)
        case .cancelled, .failed:
            startMotion(velocity: 0)
        default:
            break
        }
    }

    private func startMotion(velocity: CGFloat) {
        guard !isSuspended else {
            return
        }

        self.velocity = velocity
        guard abs(velocity) > 5 || coordinator.isBouncing else {
            return
        }

        lastTimestamp = nil
        let link = CADisplayLink(target: MotionTarget(owner: self), selector: #selector(MotionTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        let deltaTime = CGFloat(min(1.0 / 30, timestamp - (lastTimestamp ?? timestamp)))
        lastTimestamp = timestamp
        guard deltaTime > 0 else {
            return
        }

        if coordinator.isBouncing {
            if !coordinator.stepBounce(deltaTime: deltaTime, velocity: &velocity) {
                stopMotion()
            }
        } else {
            coordinator.consume(velocity * deltaTime)
            velocity *= pow(0.998, deltaTime * 1000)
            if abs(velocity) < 5, !coordinator.isBouncing {
                stopMotion()
            }
        }
    }
}

@MainActor
private final class MotionTarget: NSObject {
    private weak var owner: CollapsingContainer?

    init(owner: CollapsingContainer) {
        self.owner = owner
    }

    @objc
    func tick(_ link: CADisplayLink) {
        guard let owner else {
            link.invalidate()

            return
        }

        owner.tick(link.timestamp)
    }
}
