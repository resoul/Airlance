import LiquidUI
import Theme
import UIKit

public struct LiquidTab: Equatable {
    public let title: String
    public let badge: Int

    public init(title: String, badge: Int = 0) {
        self.title = title
        self.badge = badge
    }
}

@MainActor
public final class LiquidTabsView: UIView {
    public static let height: CGFloat = 48

    private static let tabHeight: CGFloat = 34
    private static let padding: CGFloat = 14

    public var onSelect: (@MainActor (Int) -> Void)?

    private let scrollView = UIScrollView()
    private let selection = LiquidSelectionView()
    private var labels: [UILabel] = []
    private var tabs: [LiquidTab] = []
    private var theme: AppTheme?
    private var highlighted = 0
    private var selectedIndex = 0

    override public init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.scrollsToTop = false
        scrollView.addSubview(selection)
        scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func setTabs(_ tabs: [LiquidTab]) {
        guard tabs != self.tabs else {
            return
        }

        let rebuild = tabs.count != labels.count
        self.tabs = tabs
        if rebuild {
            labels.forEach { label in
                label.removeFromSuperview()
            }
            labels = tabs.map { _ in
                let label = UILabel()
                label.textAlignment = .center
                scrollView.addSubview(label)

                return label
            }
        }
        updateLabels()
        setNeedsLayout()
    }

    public func apply(_ theme: AppTheme) {
        self.theme = theme
        backgroundColor = theme.colors.background
        selection.color = theme.colors.accent
        updateLabels()
        setNeedsLayout()
    }

    public func select(_ index: Int, animated: Bool) {
        selectedIndex = index
        highlighted = index
        selection.select(index, animated: animated)
        updateLabels()
        scrollToVisible(index, animated: animated)
    }

    public func setPosition(_ position: CGFloat) {
        selection.setInteractivePosition(position)
        let index = min(max(Int(position.rounded()), 0), max(tabs.count - 1, 0))
        if index != highlighted {
            highlighted = index
            updateLabels()
            scrollToVisible(index, animated: true)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        var x: CGFloat = 12
        let y = (bounds.height - Self.tabHeight) / 2
        var slots: [CGRect] = []
        for label in labels {
            let width = ceil(label.intrinsicContentSize.width) + Self.padding * 2
            let frame = CGRect(x: x, y: y, width: width, height: Self.tabHeight)
            label.frame = frame
            slots.append(frame)
            x += width + 4
        }
        scrollView.contentSize = CGSize(width: x + 8, height: bounds.height)
        selection.frame = CGRect(origin: .zero, size: scrollView.contentSize)
        selection.slots = slots
    }

    private func updateLabels() {
        guard let theme else {
            return
        }

        for (index, label) in labels.enumerated() where tabs.indices.contains(index) {
            let tab = tabs[index]
            let color = index == highlighted ? theme.colors.onAccent : theme.colors.textPrimary
            let font = theme.fonts.subheadline
            let text = NSMutableAttributedString(string: tab.title, attributes: [.font: font, .foregroundColor: color])
            if tab.badge > 0 {
                text.append(NSAttributedString(
                    string: "  \(tab.badge)",
                    attributes: [.font: font, .foregroundColor: color.withAlphaComponent(0.6)]
                ))
            }
            label.attributedText = text
        }
    }

    private func scrollToVisible(_ index: Int, animated: Bool) {
        guard labels.indices.contains(index) else {
            return
        }

        scrollView.scrollRectToVisible(labels[index].frame.insetBy(dx: -24, dy: 0), animated: animated)
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        let index = labels.firstIndex { label in
            label.frame.insetBy(dx: -2, dy: -6).contains(point)
        }
        if let index {
            onSelect?(index)
        }
    }
}
