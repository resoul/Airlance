import UIKit

extension BoostViewController {
    func update() {
        guard isViewLoaded, let channelID, let channel = store.channel(channelID) else {
            return
        }

        let strings = presentation.strings
        avatar.apply(PeerAvatars.descriptor(id: channel.id, name: channel.name))
        nameLabel.text = channel.name
        placeLabel.attributedText = header(for: channel)
        updateLevel(channel)
        star.canBoost = store.canBoost(1, to: target)
        star.canSuperBoost = store.canBoost(2, to: target)
        star.refresh()
        let one = String(store.cost(1, to: target))
        let two = String(store.cost(2, to: target))
        costLabel.text = star.canSuperBoost || !star.canBoost
            ? strings.boostCost(one, two)
            : strings.boostCost(one, "—") + "\n" + strings.boostSuperUnavailable
        let budget = strings.boostBudget(String(store.remaining), String(OnAirStore.weeklyBudget))
        budgetLabel.text = budget + "\n" + strings.boostReset(Self.relative(store.resetDate, strings: strings))
        budgetBar.setProgress(Float(store.remaining) / Float(OnAirStore.weeklyBudget), animated: true)
        mineLabel.text = strings.boostMine(String(store.myVotes(target)))
        view.setNeedsLayout()
    }

    private func header(for channel: OnAirChannel) -> NSAttributedString {
        let theme = presentation.theme
        let strings = presentation.strings
        let secondary: [NSAttributedString.Key: Any] = [.foregroundColor: theme.colors.textSecondary]
        let accent: [NSAttributedString.Key: Any] = [.foregroundColor: theme.colors.accent]
        guard case .post(let id) = target, let post = store.post(id) else {
            let text = NSMutableAttributedString(
                string: strings.boostPlace(String(store.rank(of: channel.id)?.rank ?? 0)),
                attributes: secondary
            )
            text.append(NSAttributedString(string: "  ★ " + strings.compactCount(channel.score), attributes: accent))

            return text
        }

        let text = NSMutableAttributedString(string: "«" + post.text + "»\n", attributes: secondary)
        text.append(NSAttributedString(string: "★ " + strings.compactCount(post.boosts), attributes: accent))

        return text
    }

    private func updateLevel(_ channel: OnAirChannel) {
        let strings = presentation.strings
        let level = OnAirLevel(score: channel.score)
        levelLabel.isHidden = target != .channel(channel.id)
        let text = NSMutableAttributedString(
            string: level.title(strings),
            attributes: [.foregroundColor: level.color]
        )
        text.insert(level.badge(font: levelLabel.font), at: 0)
        if let next = level.next {
            let left = strings.compactCount(next.threshold - channel.score)
            text.append(NSAttributedString(
                string: "  " + strings.onAirLevelNext(next.title(strings), left),
                attributes: [.foregroundColor: presentation.theme.colors.textSecondary]
            ))
        }
        levelLabel.attributedText = text
        levelBar.progressTintColor = (level.next ?? level).color
        levelBar.setProgress(Float(OnAirLevel.progress(score: channel.score)), animated: true)
    }

    private static func relative(_ date: Date, strings: AppStrings) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = strings.pack.locale
        formatter.unitsStyle = .full

        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension BoostViewController {
    static func present(
        _ target: BoostTarget,
        store: OnAirStore,
        presentationSource: PresentationContext,
        from presenter: UIViewController
    ) {
        let boost = BoostViewController(target: target, store: store, presentationSource: presentationSource)
        boost.modalPresentationStyle = .pageSheet
        if let sheet = boost.sheetPresentationController {
            let height = UISheetPresentationController.Detent.custom { context in
                min(800, context.maximumDetentValue)
            }
            sheet.detents = [height, .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(boost, animated: true)
    }
}
