import UIKit

enum OnAirCategory: String, CaseIterable, Sendable {
    case tech
    case design
    case news
    case sport
    case music
    case science
    case games
}

enum OnAirSection: Int, CaseIterable, Sendable {
    case onAir
    case rising
    case new
    case news
}

struct OnAirChannel: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let category: OnAirCategory
    let subscribers: Int
    let score: Int
    let boosts: Int
    let previousRank: Int?
    let growth: Int
    let ageDays: Int
}

struct OnAirPost: Identifiable, Sendable, Hashable {
    let id: String
    let channelID: String
    let text: String
    let date: Date
    let views: Int
    let reactions: Int
    let boosts: Int
    let comments: Int
}

struct RankedChannel: Sendable, Equatable {
    let channel: OnAirChannel
    let rank: Int

    var delta: Int? {
        channel.previousRank.map { previous in
            previous - rank
        }
    }
}

enum OnAirLevel: Int, CaseIterable, Sendable {
    static let medals: [UIColor] = [
        UIColor(red: 1, green: 0.78, blue: 0.2, alpha: 1),
        UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1),
        UIColor(red: 0.85, green: 0.52, blue: 0.3, alpha: 1),
    ]

    case none
    case bronze
    case silver
    case gold
    case diamond

    var threshold: Int {
        switch self {
        case .none:
            0
        case .bronze:
            2000
        case .silver:
            5000
        case .gold:
            8000
        case .diamond:
            12_000
        }
    }

    var next: OnAirLevel? {
        OnAirLevel(rawValue: rawValue + 1)
    }

    init(score: Int) {
        self = Self.allCases.last { level in
            score >= level.threshold
        } ?? .none
    }

    static func progress(score: Int) -> Double {
        let level = OnAirLevel(score: score)
        guard let next = level.next else {
            return 1
        }

        return Double(score - level.threshold) / Double(next.threshold - level.threshold)
    }
}
