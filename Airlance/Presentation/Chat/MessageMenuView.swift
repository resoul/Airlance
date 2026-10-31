import AirlanceUI
import Haptics
import ReactionsUI
import UIKit

struct MessageMenuReactions {
    let chosen: String?
    let pick: @MainActor (String) -> Void
}

struct MessageMenuExtras {
    var selection: MessageMenuSelection?
    var reactions: MessageMenuReactions?
    var receipts: MessageMenuReceipts?
}

struct MessageMenuSelection {
    let text: SelectableText
    let items: @MainActor (String, NSRange) -> [MenuItem]
}

final class MessageMenuView: UIView, FocusOverlay {
    static let menuWidth: CGFloat = 250

    private let blur = UIVisualEffectView(effect: nil)
    private let liftedClip = PassthroughView()
    private let liftedMask = UIView()
    private let lifted: UIView
    private let source: CGRect
    private let visible: CGRect
    var target: CGRect
    let menu: MenuListView
    let outgoing: Bool
    private let baseItems: [MenuItem]
    private var selectionView: TextSelectionView?
    private var reactionBar: ReactionBarView?
    private var pickReaction: (@MainActor (String) -> Void)?
    private var gate = MenuGestureGate()
    var receiptsPanel: MessageReceiptsPanel?

    init(
        bubble: UIView,
        frame bubbleFrame: CGRect,
        outgoing: Bool,
        items: [MenuItem],
        presentation: PresentationData,
        visible: CGRect,
        extras: MessageMenuExtras,
        host: UIView
    ) {
        source = bubble.convert(bubbleFrame, to: host)
        self.visible = visible
        let snapshot = bubble.resizableSnapshotView(from: bubbleFrame, afterScreenUpdates: false, withCapInsets: .zero)
        lifted = snapshot ?? UIView()
        target = source
        self.outgoing = outgoing
        baseItems = items
        menu = MenuListView(presentation: presentation)
        super.init(frame: host.bounds)
        host.addSubview(self)
        blur.frame = bounds
        blur.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        addSubview(blur)

        let barSpace = extras.reactions == nil ? 0 : ReactionBarView.height + 10
        let receiptsSpace = extras.receipts == nil ? 0 : MessageReceiptsPanel.summaryHeight + 6
        let menuHeight = MenuListView.rowHeight * CGFloat(items.count) + receiptsSpace
        placeTarget(in: host, menuHeight: menuHeight, topSpace: barSpace)
        installLifted()
        if let selection = extras.selection {
            addSelection(selection, origin: bubbleFrame.origin, color: presentation.theme.colors.accent)
        }
        if let reactions = extras.reactions {
            addReactionBar(reactions, presentation: presentation)
        }
        if let receipts = extras.receipts {
            addReceipts(receipts, presentation: presentation)
        }
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
            self.reactionBar?.alpha = 1
            self.reactionBar?.transform = .identity
            self.receiptsPanel?.alpha = 1
            self.receiptsPanel?.transform = .identity
        } completion: { _ in
            self.gate.isReady = true
        }
    }

    func track(_ point: CGPoint, ended: Bool) {
        guard isUserInteractionEnabled, receiptsPanel?.isExpanded != true else {
            return
        }

        let isOpen = gate.allows(point)
        if isOpen, let bar = reactionBar, bar.track(convert(point, to: bar)) {
            menu.track(CGPoint(x: -1, y: -1), ended: false)
            if ended, let emoji = bar.release(), let pick = pickReaction {
                close {
                    pick(emoji)
                }
            }

            return
        }

        if ended {
            _ = reactionBar?.release()
        }
        menu.track(isOpen ? convert(point, to: menu) : CGPoint(x: -1, y: -1), ended: ended)
    }

    private func show(_ items: [MenuItem]) {
        menu.setItems(items)
        let width = Self.menuWidth
        let height = menu.contentHeight
        let x = menuX
        let top = target.maxY + 8 + (receiptsPanel == nil ? 0 : MessageReceiptsPanel.summaryHeight + 6)
        menu.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        menu.center = CGPoint(x: x + width / 2, y: top + height / 2)
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

    private func placeTarget(in host: UIView, menuHeight: CGFloat, topSpace: CGFloat) {
        let top = host.safeAreaInsets.top + 12 + topSpace
        let bottom = host.bounds.height - host.safeAreaInsets.bottom - 12 - menuHeight - 8
        target.size.height = min(source.height, max(0, bottom - top))
        target.origin.y = min(max(source.minY, top), bottom - target.height)
    }

    private func installLifted() {
        lifted.frame = source
        lifted.clipsToBounds = true
        liftedClip.frame = bounds
        liftedMask.frame = bounds
        liftedMask.backgroundColor = .black
        liftedClip.mask = liftedMask
        liftedClip.addSubview(lifted)
        addSubview(liftedClip)
    }

    private func addReactionBar(_ reactions: MessageMenuReactions, presentation: PresentationData) {
        let bar = ReactionBarView(
            quick: Reactions.quick,
            more: Reactions.more,
            chosen: reactions.chosen,
            theme: presentation.theme
        )
        let width = bar.bounds.width
        let x = outgoing ? max(12, target.maxX - width) : min(max(12, target.minX), bounds.width - width - 12)
        bar.frame.origin = CGPoint(x: x, y: target.minY - ReactionBarView.height - 10)
        bar.alpha = 0
        bar.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        bar.onPick = { [weak self] emoji in
            self?.close {
                reactions.pick(emoji)
            }
        }
        bar.onExpand = { [weak self] expanded in
            UIView.animate(withDuration: 0.2) {
                self?.menu.alpha = expanded ? 0 : 1
            }
            self?.menu.isUserInteractionEnabled = !expanded
        }
        addSubview(bar)
        reactionBar = bar
        pickReaction = reactions.pick
    }

    func close(_ completion: (@MainActor () -> Void)?) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.menu.alpha = 0
            self.menu.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.reactionBar?.alpha = 0
            self.reactionBar?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.receiptsPanel?.alpha = 0
            self.receiptsPanel?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.lifted.transform = .identity
            self.lifted.frame = self.source
            self.liftedMask.frame = self.visible
            self.blur.effect = nil
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    private func addSelection(_ selection: MessageMenuSelection, origin: CGPoint, color: UIColor) {
        let text = selection.text
        let local = SelectableText(
            text: text.text,
            attributed: text.attributed,
            frame: text.frame.offsetBy(dx: -origin.x, dy: -origin.y)
        )
        let view = TextSelectionView(source: local, color: color)
        view.onChange = { [weak self, weak view] range in
            guard let self else {
                return
            }

            let items = range.flatMap { range in
                view?.selectedText.map { text in
                    selection.items(text, range)
                }
            }
            self.replaceItems(items ?? self.baseItems)
        }
        lifted.addSubview(view)
        selectionView = view
    }

    private func replaceItems(_ items: [MenuItem]) {
        UIView.transition(with: menu, duration: 0.2, options: .transitionCrossDissolve) {
            self.show(items)
        }
    }
}

private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)

        return view === self ? nil : view
    }
}
