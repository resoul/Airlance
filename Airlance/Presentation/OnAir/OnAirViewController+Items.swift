import ListUI
import UIKit

extension OnAirViewController {
    func channelItems() -> [any ListItem] {
        let ranked = dependencies.store.ranked(section, category: category).filter { entry in
            !onlyMine || isJoined(entry.channel.id)
        }
        let podium = section == .onAir ? Array(ranked.prefix(3)) : []
        let rows = Array(ranked.dropFirst(podium.count))
        var items: [any ListItem] = []
        if !podium.isEmpty {
            items.append(OnAirPodiumItem(
                entries: podium,
                values: podium.map { entry in
                    "★ " + presentation.strings.compactCount(entry.channel.score)
                },
                onSelect: { [weak self] id in
                    self?.open(id)
                }
            ))
        }
        for (index, entry) in rows.enumerated() {
            let position = section == .onAir ? entry.rank : index + 1
            items.append(channelItem(entry, position: position, showsSeparator: index < rows.count - 1))
        }

        return items
    }

    func newsItems() -> [any ListItem] {
        let strings = presentation.strings
        let store = dependencies.store
        let now = Date()
        let posts = store.news(category: category, options: newsOptions, keeping: keptPosts, now: now)
            .filter { post in
                !onlyMine || isJoined(post.channelID)
            }
        keptPosts.formUnion(posts.map(\.id))

        return posts.enumerated().compactMap { index, post in
            guard let channel = store.channel(post.channelID) else {
                return nil
            }

            return OnAirPostItem(
                post: post,
                channel: channel,
                time: dateFormatter.string(for: post.date, now: now),
                views: strings.compactCount(post.views),
                boosts: strings.compactCount(post.boosts),
                comments: strings.compactCount(post.comments),
                level: OnAirLevel(score: channel.score),
                isJoined: isJoined(channel.id),
                showsSeparator: index < posts.count - 1,
                swipe: swipe(for: channel),
                onVisible: { [weak self] isVisible in
                    self?.setPostVisible(post.id, isVisible: isVisible)
                },
                onLongPress: { [weak self] in
                    self?.boostPost(post.id)
                },
                onSelect: { [weak self] in
                    self?.open(channel.id)
                }
            )
        }
    }

    private func swipe(for channel: OnAirChannel) -> ListSwipeActions {
        let hide = ListSwipeAction(
            title: presentation.strings.onAirNotInterested,
            symbol: "eye.slash",
            color: .systemGray
        ) { [weak self] in
            self?.hideChannel(channel)
        }

        return ListSwipeActions(trailing: [hide])
    }

    private func channelItem(_ entry: RankedChannel, position: Int, showsSeparator: Bool) -> OnAirChannelItem {
        let strings = presentation.strings
        let channel = entry.channel
        let subtitle = strings.onAirTitle(channel.category) + " · " + strings.onAirSubscribers(channel.subscribers)
        let colors = presentation.theme.colors
        let score = OnAirBadge(text: "★ " + strings.compactCount(channel.score), color: colors.accent)
        let value: OnAirBadge
        let detail: OnAirBadge
        switch section {
        case .rising:
            value = OnAirBadge(text: "+\(channel.growth) %", color: .systemGreen)
            detail = score
        case .new:
            value = score
            detail = OnAirBadge(text: strings.onAirDaysAgo(String(channel.ageDays)), color: colors.textSecondary)
        case .onAir, .news:
            value = score
            detail = deltaBadge(entry.delta)
        }

        return OnAirChannelItem(
            channel: channel,
            position: position,
            subtitle: subtitle,
            value: value,
            detail: detail,
            level: OnAirLevel(score: channel.score),
            isJoined: isJoined(channel.id),
            showsSeparator: showsSeparator
        ) { [weak self] in
            self?.open(channel.id)
        }
    }

    private func deltaBadge(_ delta: Int?) -> OnAirBadge {
        let colors = presentation.theme.colors
        guard let delta else {
            return OnAirBadge(text: presentation.strings.onAirNew, color: colors.accent)
        }

        if delta > 0 {
            return OnAirBadge(text: "▲ \(delta)", color: .systemGreen)
        } else if delta < 0 {
            return OnAirBadge(text: "▼ \(-delta)", color: .systemRed)
        }

        return OnAirBadge(text: "—", color: colors.textSecondary)
    }
}
