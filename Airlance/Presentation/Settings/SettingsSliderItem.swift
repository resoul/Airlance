@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct SettingsSliderItem: ListItem {
    let id: String
    let value: Int
    var range = 0...100
    var step = 5
    let leftTitle: String
    let rightTitle: String
    let title: @MainActor @Sendable (Int) -> String
    let onChange: @MainActor (Int) -> Void

    var version: Int {
        var hasher = Hasher()
        hasher.combine(value)
        hasher.combine(range)
        hasher.combine(step)
        hasher.combine(leftTitle)
        hasher.combine(rightTitle)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        104
    }

    func makeNode() -> ListItemNode {
        SettingsSliderNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? SettingsSliderNode)?.update(self, theme: theme)
    }

    func snapped(_ value: Float) -> Int {
        let steps = ((value - Float(range.lowerBound)) / Float(step)).rounded()

        return min(max(range.lowerBound + Int(steps) * step, range.lowerBound), range.upperBound)
    }
}

final class SettingsSliderNode: ListItemNode {
    private let card = ASDisplayNode()
    private let left = ASTextNode()
    private let right = ASTextNode()
    private let title = ASTextNode()
    private let slider = ASDisplayNode {
        UISlider()
    }
    private var item: SettingsSliderItem?
    private var theme = ListTheme()
    private var shown = -1

    override func didLoad() {
        super.didLoad()
        for node in [card, left, right, title] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        addSubnode(slider)
        guard let view = slider.view as? UISlider else {
            return
        }

        view.addAction(UIAction { [weak self] _ in
            self?.moved()
        }, for: .valueChanged)
        view.addAction(UIAction { [weak self] _ in
            self?.released()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    func update(_ item: SettingsSliderItem, theme: ListTheme) {
        self.item = item
        self.theme = theme
        backgroundColor = theme.background
        card.backgroundColor = theme.rowBackground
        left.attributedText = Self.text(item.leftTitle, font: theme.subtitleFont, color: theme.secondary)
        right.attributedText = Self.text(item.rightTitle, font: theme.subtitleFont, color: theme.secondary)
        if let view = slider.view as? UISlider, !view.isTracking {
            view.minimumTrackTintColor = theme.accent
            view.minimumValue = Float(item.range.lowerBound)
            view.maximumValue = Float(item.range.upperBound)
            view.value = Float(item.value)
            show(item.value)
        }
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        card.frame = bounds.insetBy(dx: 16, dy: 0)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        let inner = card.frame.insetBy(dx: 16, dy: 0)
        let range = ASSizeRange(min: .zero, max: CGSize(width: inner.width / 2, height: 30))
        let leftSize = left.layoutThatFits(range).size
        let rightSize = right.layoutThatFits(range).size
        left.frame = CGRect(x: inner.minX, y: 20, width: leftSize.width, height: leftSize.height)
        right.frame = CGRect(x: inner.maxX - rightSize.width, y: 20, width: rightSize.width, height: rightSize.height)
        let titleRange = ASSizeRange(min: .zero, max: CGSize(width: inner.width - 120, height: 30))
        let titleSize = title.layoutThatFits(titleRange).size
        title.frame = CGRect(origin: CGPoint(x: card.frame.midX - titleSize.width / 2, y: 18), size: titleSize)
        slider.frame = CGRect(x: inner.minX, y: 54, width: inner.width, height: 34)
    }

    private func show(_ value: Int) {
        guard value != shown, let item else {
            return
        }

        shown = value
        title.attributedText = Self.text(item.title(value), font: theme.titleFont, color: theme.primary)
        setNeedsLayout()
    }

    private func moved() {
        guard let view = slider.view as? UISlider, let item else {
            return
        }

        let value = item.snapped(view.value)
        if value != shown {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        show(value)
    }

    private func released() {
        guard let view = slider.view as? UISlider, let item else {
            return
        }

        let value = item.snapped(view.value)
        view.setValue(Float(value), animated: true)
        item.onChange(value)
    }

    private static func text(_ string: String, font: UIFont, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }
}
