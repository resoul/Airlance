import Foundation

extension OnAirStore {
    var channels: [OnAirChannel] {
        base.map(boosted)
    }

    var posts: [OnAirPost] {
        basePosts.map(boosted)
    }

    var spent: Int {
        weekVotes.values.reduce(0) { total, count in
            total + count * count
        }
    }

    var remaining: Int {
        max(0, Self.weeklyBudget - spent)
    }

    var resetDate: Date {
        Self.calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, weekday: 2),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(7 * 86_400)
    }

    func channel(_ id: String) -> OnAirChannel? {
        base
            .first { channel in
                channel.id == id
            }
            .map(boosted)
    }

    func post(_ id: String) -> OnAirPost? {
        basePosts
            .first { post in
                post.id == id
            }
            .map(boosted)
    }

    func rank(of id: String) -> RankedChannel? {
        ranked(.onAir, category: nil).first { entry in
            entry.channel.id == id
        }
    }

    func cost(_ added: Int, to target: BoostTarget) -> Int {
        let current = weekVotes[target.key, default: 0]

        return (current + added) * (current + added) - current * current
    }

    func canBoost(_ added: Int, to target: BoostTarget) -> Bool {
        cost(added, to: target) <= remaining
    }

    func myVotes(_ target: BoostTarget) -> Int {
        switch target {
        case .channel(let id):
            votes[id, default: 0]
        case .post(let id):
            postVotes[id, default: 0]
        }
    }

    func ranked(_ section: OnAirSection, category: OnAirCategory?) -> [RankedChannel] {
        let all = channels
        let ranks = Dictionary(uniqueKeysWithValues: all.sorted(by: Self.byScore).enumerated().map { index, channel in
            (channel.id, index + 1)
        })
        let filtered = all.filter { channel in
            category == nil || channel.category == category
        }
        let sorted: [OnAirChannel] = switch section {
        case .rising:
            filtered.sorted { lhs, rhs in
                lhs.growth > rhs.growth
            }
        case .new:
            filtered
                .filter { channel in
                    channel.ageDays <= Self.newDays
                }
                .sorted(by: Self.byScore)
        case .onAir, .news:
            filtered.sorted(by: Self.byScore)
        }

        return sorted.map { channel in
            RankedChannel(channel: channel, rank: ranks[channel.id] ?? 0)
        }
    }

    private func boosted(_ channel: OnAirChannel) -> OnAirChannel {
        let direct = votes[channel.id, default: 0]
        let throughPosts = basePosts
            .filter { post in
                post.channelID == channel.id
            }
            .reduce(0) { total, post in
                total + postVotes[post.id, default: 0]
            }
        guard direct + throughPosts > 0 else {
            return channel
        }

        return OnAirChannel(
            id: channel.id,
            name: channel.name,
            category: channel.category,
            subscribers: channel.subscribers,
            score: channel.score + direct * Self.voteWeight + throughPosts * Self.postVoteWeight,
            boosts: channel.boosts + direct + throughPosts,
            previousRank: channel.previousRank,
            growth: channel.growth,
            ageDays: channel.ageDays
        )
    }

    private func boosted(_ post: OnAirPost) -> OnAirPost {
        let count = postVotes[post.id, default: 0]
        guard count > 0 else {
            return post
        }

        return OnAirPost(
            id: post.id,
            channelID: post.channelID,
            text: post.text,
            date: post.date,
            views: post.views,
            reactions: post.reactions,
            boosts: post.boosts + count,
            comments: post.comments
        )
    }

    private static func byScore(_ lhs: OnAirChannel, _ rhs: OnAirChannel) -> Bool {
        lhs.score > rhs.score
    }
}
