import Haptics
import LiquidUI
import UIKit

@MainActor
public final class StoriesHeaderView: UIView, UIScrollViewDelegate {
    public static let barHeight: CGFloat = 44
    public static let rowHeight: CGFloat = 86

    static let stackCount = 3
    static let stackSize: CGFloat = 26
    static let stackStep: CGFloat = 15
    static let expandedSize: CGFloat = 52
    static let slotWidth: CGFloat = 74
    static let rowInset: CGFloat = 6

    public var onOpen: (@MainActor (String) -> Void)?
    public var onStackTap: (@MainActor () -> Void)?

    public var title = "" {
        didSet {
            titleLabel.text = title
            setNeedsLayout()
        }
    }
    public var safeTop: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }
    public var trailingView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let trailingView {
                addSubview(trailingView)
            }
            setNeedsLayout()
        }
    }
    public var theme = StoriesHeaderTheme() {
        didSet {
            applyTheme()
        }
    }

    public private(set) var expansion: CGFloat = 0

    public var visibleHeight: CGFloat {
        safeTop + Self.barHeight + Self.rowHeight * expansion
    }

    let background = UIView()
    let titleLabel = UILabel()
    let canvas = LiquidCanvasView()
    let rowScroll = UIScrollView()
    var entries: [StoryStripEntry] = []
    private lazy var stackTap = UITapGestureRecognizer(target: self, action: #selector(stackTapped))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(background)
        addSubview(canvas)
        addSubview(titleLabel)
        canvas.gloss = 0.5
        canvas.rimWidth = 4
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }

        rowScroll.delegate = self
        rowScroll.showsHorizontalScrollIndicator = false
        rowScroll.alwaysBounceHorizontal = true
        rowScroll.backgroundColor = .clear
        rowScroll.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:))))
        addSubview(rowScroll)
        addGestureRecognizer(stackTap)
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func setPeers(_ peers: [StoryPeer]) {
        let reusable = Dictionary(entries.map { entry in
            (entry.peer.id, entry)
        }) { first, _ in
            first
        }
        let next = peers.enumerated().map { index, peer in
            if let entry = reusable[peer.id] {
                entry.update(peer)

                return entry
            }

            return StoryStripEntry(peer: peer, index: index)
        }
        let kept = Set(next.map(\.peer.id))
        for entry in entries where !kept.contains(entry.peer.id) {
            entry.container.removeFromSuperview()
            entry.name.removeFromSuperview()
        }
        entries = next
        for entry in entries.reversed() {
            insertSubview(entry.name, belowSubview: rowScroll)
            insertSubview(entry.container, belowSubview: rowScroll)
            entry.apply(theme, traits: traitCollection)
        }
        rowScroll.contentSize = CGSize(
            width: Self.rowInset * 2 + Self.slotWidth * CGFloat(entries.count),
            height: Self.rowHeight
        )
        wake()
        setNeedsLayout()
    }

    public func setExpansion(_ fraction: CGFloat) {
        let value = min(max(fraction, 0), 1)
        guard value != expansion else {
            return
        }

        expansion = value
        rowScroll.isUserInteractionEnabled = value > 0.9
        place()
        wake()
    }

    public func avatarFrame(for id: String, in view: UIView) -> CGRect? {
        guard let entry = entries.first(where: { entry in
            entry.peer.id == id
        }) else {
            return nil
        }

        return entry.container.convert(entry.container.bounds, to: view)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds
        rowScroll.frame = CGRect(
            x: 0,
            y: safeTop + Self.barHeight,
            width: bounds.width,
            height: Self.rowHeight
        )
        trailingView?.frame = CGRect(
            x: bounds.width - 52,
            y: safeTop,
            width: 44,
            height: Self.barHeight
        )
        place()
        canvas.render()
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard point.y <= visibleHeight else {
            return nil
        }

        return super.hitTest(point, with: event)
    }

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === stackTap else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        return expansion < 0.5 && stackArea.contains(gestureRecognizer.location(in: self))
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        place()
        canvas.render()
    }

    func wake() {
        canvas.startFrames()
    }

    private func step(_ deltaTime: CFTimeInterval) {
        var settled = true
        for (index, entry) in entries.enumerated() {
            let delay = CGFloat(min(index, 6)) * 0.06
            let target = min(max((expansion - delay) / (1 - 0.36), 0), 1)
            entry.spring.step(toward: target, deltaTime: deltaTime)
            if !entry.spring.isSettled(at: target, tolerance: 0.002) {
                settled = false
            }
        }
        place()
        if settled {
            canvas.stopFrames()
        }
    }

    private func applyTheme() {
        background.backgroundColor = theme.background
        titleLabel.font = theme.titleFont
        titleLabel.textColor = theme.title
        canvas.color = theme.unseen
        for entry in entries {
            entry.apply(theme, traits: traitCollection)
        }
        setNeedsLayout()
    }

    @objc
    private func stackTapped() {
        onStackTap?()
    }

    @objc
    private func rowTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: rowScroll)
        let index = Int(((point.x - Self.rowInset) / Self.slotWidth).rounded(.down))
        guard entries.indices.contains(index), point.x >= Self.rowInset else {
            return
        }

        let entry = entries[index]
        Haptics.play(.tap)
        UIView.animate(withDuration: 0.12, animations: {
            entry.container.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                entry.container.transform = .identity
            }
        })
        onOpen?(entry.peer.id)
    }
}
