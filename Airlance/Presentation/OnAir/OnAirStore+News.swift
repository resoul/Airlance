import Foundation

struct OnAirNewsOptions: Equatable {
    var latestOnly = false
    var showsSeen = false
}

extension OnAirStore {
    func news(
        category: OnAirCategory?,
        options: OnAirNewsOptions,
        keeping: Set<String> = [],
        now: Date
    ) -> [OnAirPost] {
        let all = channels
        let top = Double(all.map(\.score).max() ?? 1)
        let byID = Dictionary(uniqueKeysWithValues: all.map { channel in
            (channel.id, channel)
        })
        var visible = posts.filter { post in
            let isFresh = options.showsSeen || keeping.contains(post.id) || !seen.contains(post.id)

            return isFresh && !hidden.contains(post.channelID)
        }
        if options.latestOnly {
            visible = Self.latest(visible)
        }
        let scored = visible.compactMap { post -> (OnAirPost, Double)? in
            guard let channel = byID[post.channelID], category == nil || channel.category == category else {
                return nil
            }

            let actions = post.reactions * 2 + post.boosts * 8 + post.comments * 3
            let engagement = Double(post.views) / 1000 + Double(actions)
            let hours = max(0, now.timeIntervalSince(post.date) / 3600)
            let weight = (Double(channel.score) / top + 0.2) * engagement / pow(hours + 2, 1.5)

            return (post, weight)
        }
        let sorted = scored
            .sorted { lhs, rhs in
                lhs.1 > rhs.1
            }
            .map(\.0)

        return Self.spread(sorted, maxInRow: 2)
    }

    private static func latest(_ posts: [OnAirPost]) -> [OnAirPost] {
        var latest: [String: OnAirPost] = [:]
        for post in posts where post.date > latest[post.channelID]?.date ?? .distantPast {
            latest[post.channelID] = post
        }

        return posts.filter { post in
            latest[post.channelID]?.id == post.id
        }
    }

    private static func spread(_ posts: [OnAirPost], maxInRow: Int) -> [OnAirPost] {
        var pending = posts
        var result: [OnAirPost] = []
        while !pending.isEmpty {
            let tail = result.suffix(maxInRow).map(\.channelID)
            let blocked = tail.count == maxInRow && Set(tail).count == 1 ? tail.first : nil
            let index = pending.firstIndex { post in
                post.channelID != blocked
            } ?? 0
            result.append(pending.remove(at: index))
        }

        return result
    }
}
