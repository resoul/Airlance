import Haptics
import UIKit

extension StoryViewerController {
    func handleWidgetTap(_ point: CGPoint) -> Bool {
        if answerView != nil {
            return true
        }

        if let tooltip {
            if tooltip.frame.insetBy(dx: -8, dy: -8).contains(point) {
                onInteraction?(tooltip.action)
            }
            dismissTooltip()

            return true
        }

        guard let page, let item = page.item,
              let (entity, widgetView) = page.widgets.widget(at: page.widgets.convert(point, from: view)),
              let widget = entity.widget else {
            return false
        }

        act(on: widget, entity: entity, view: widgetView, item: item.id, point: point)

        return true
    }

    func dismissTooltip() {
        guard let tooltip else {
            return
        }

        tooltip.disappear()
        self.tooltip = nil
        setInteracting(false)
    }

    private func act(
        on widget: StoryWidget,
        entity: StoryEntity,
        view widgetView: StoryWidgetView,
        item: String,
        point: CGPoint
    ) {
        switch widget.kind {
        case .mention(let peer):
            showTooltip(.openProfile, action: .openPeer(peer.id), over: widgetView)
        case .location(let place):
            showTooltip(.openMap, action: .openPlace(place), over: widgetView)
        case .link(let url, _):
            showTooltip(.openLink, action: .openLink(url), over: widgetView)
        case .addYours(let prompt, _):
            showTooltip(.addYoursAction, action: .addYours(prompt: prompt), over: widgetView)
        case .reaction(let emoji):
            widgetView.pop()
            burst(emoji, from: widgetView)
            Haptics.play(.success)
            onInteraction?(.react(item: item, emoji: emoji))
        case .poll:
            vote(entity: entity, view: widgetView, item: item, point: point)
        case .question(let prompt, let hint):
            showAnswer(prompt: prompt, hint: hint, tint: widget.tint.uiColor, widget: entity.id, item: item)
        }
    }

    func label(_ key: StoryLabel) -> String {
        labels[key] ?? key.rawValue
    }

    private func setInteracting(_ isInteracting: Bool) {
        self.isInteracting = isInteracting
        page?.media.setPaused(isInteracting || isHeld)
    }

    private func showTooltip(_ title: StoryLabel, action: StoryInteraction, over widgetView: StoryWidgetView) {
        if case .openPeer(let id) = action, id.isEmpty {
            return
        }

        let tooltip = StoryTooltipView(title: label(title), action: action)
        tooltip.place(
            near: widgetView.convert(widgetView.bounds, to: view),
            in: view.bounds,
            safeTop: view.safeAreaInsets.top
        )
        view.addSubview(tooltip)
        tooltip.appear()
        self.tooltip = tooltip
        setInteracting(true)
        Haptics.play(.selection)
    }

    private func vote(entity: StoryEntity, view widgetView: StoryWidgetView, item: String, point: CGPoint) {
        guard votes[entity.id] == nil,
              let option = widgetView.option(at: widgetView.convert(point, from: view)) else {
            return
        }

        votes[entity.id] = option
        page?.votes = votes
        UIView.animate(withDuration: 0.25) {
            widgetView.vote = option
        }
        Haptics.play(.success)
        onInteraction?(.vote(item: item, widget: entity.id, option: option))
    }
}
