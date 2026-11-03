import DatabaseAPI
import Foundation
import Observers

extension StorageKey where Value == [String] {
    static let onAirVotes = StorageKey("onAir.votes", default: [])
    static let onAirPostVotes = StorageKey("onAir.postVotes", default: [])
    static let onAirWeekVotes = StorageKey("onAir.weekVotes", default: [])
    static let onAirSeen = StorageKey("onAir.seen", default: [])
    static let onAirHidden = StorageKey("onAir.hidden", default: [])
}

extension StorageKey where Value == String {
    static let onAirWeek = StorageKey("onAir.week", default: "")
}

enum BoostTarget: Hashable, Sendable {
    case channel(String)
    case post(String)

    var key: String {
        switch self {
        case .channel(let id):
            "c:" + id
        case .post(let id):
            "p:" + id
        }
    }
}

@MainActor
final class OnAirStore {
    static let newDays = 30
    static let weeklyBudget = 10
    static let voteWeight = 40
    static let postVoteWeight = 10

    let base: [OnAirChannel]
    let basePosts: [OnAirPost]
    private let storage: any KeyValueStore
    private let observers = ObserverList<Int>()
    private(set) var votes: [String: Int]
    private(set) var postVotes: [String: Int]
    private(set) var weekVotes: [String: Int]
    private(set) var seen: Set<String>
    private(set) var hidden: Set<String>
    private var week: String
    private var revision = 0

    init(channels: [OnAirChannel], posts: [OnAirPost], storage: any KeyValueStore) {
        base = channels
        basePosts = posts
        self.storage = storage
        votes = Self.decode(storage.value(for: .onAirVotes))
        postVotes = Self.decode(storage.value(for: .onAirPostVotes))
        weekVotes = Self.decode(storage.value(for: .onAirWeekVotes))
        seen = Set(storage.value(for: .onAirSeen))
        hidden = Set(storage.value(for: .onAirHidden))
        week = storage.value(for: .onAirWeek)
        startWeekIfNeeded(now: Date())
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (Int) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    @discardableResult
    func boost(_ target: BoostTarget, votes added: Int) -> Bool {
        startWeekIfNeeded(now: Date())
        guard added > 0, canBoost(added, to: target) else {
            return false
        }

        weekVotes[target.key, default: 0] += added
        switch target {
        case .channel(let id):
            votes[id, default: 0] += added
            save(.onAirVotes, Self.encode(votes))
        case .post(let id):
            postVotes[id, default: 0] += added
            save(.onAirPostVotes, Self.encode(postVotes))
        }
        save(.onAirWeekVotes, Self.encode(weekVotes))
        changed()

        return true
    }

    func markSeen(posts ids: [String], notify: Bool = true) {
        let fresh = ids.filter { id in
            !seen.contains(id)
        }
        guard !fresh.isEmpty else {
            return
        }

        seen.formUnion(fresh)
        save(.onAirSeen, Array(seen).sorted())
        if notify {
            changed()
        }
    }

    func markSeen(channel id: String) {
        markSeen(posts: basePosts
            .filter { post in
                post.channelID == id
            }
            .map(\.id))
    }

    func setHidden(_ isHidden: Bool, channel id: String) {
        guard hidden.contains(id) != isHidden else {
            return
        }

        if isHidden {
            hidden.insert(id)
        } else {
            hidden.remove(id)
        }
        save(.onAirHidden, Array(hidden).sorted())
        changed()
    }

    private func startWeekIfNeeded(now: Date) {
        let current = Self.weekID(for: now)
        guard current != week else {
            return
        }

        week = current
        weekVotes = [:]
        save(.onAirWeekVotes, [])
        let storage = storage
        Task {
            try? await storage.update(.onAirWeek) { value in
                value = current
            }
        }
    }

    private func save(_ key: StorageKey<[String]>, _ value: [String]) {
        let storage = storage
        Task {
            try? await storage.update(key) { stored in
                stored = value
            }
        }
    }

    private func changed() {
        revision += 1
        observers.notify(revision)
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current

        return calendar
    }

    private static func weekID(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)

        return "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
    }

    private static func decode(_ items: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for item in items {
            let parts = item.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let count = Int(parts[1]), count > 0 else {
                continue
            }

            result[String(parts[0])] = count
        }

        return result
    }

    private static func encode(_ values: [String: Int]) -> [String] {
        values.keys.sorted().map { key in
            "\(key)=\(values[key, default: 0])"
        }
    }
}
