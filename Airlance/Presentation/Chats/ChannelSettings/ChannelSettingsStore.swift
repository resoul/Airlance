import DatabaseAPI
import Foundation
import Observers
import Theme

enum ChannelSettingsPage: String, Sendable {
    case main
    case type
    case subscribers
    case admins
    case banned
    case log
    case boosts
    case appearance
}

enum ChannelLogKind: String, Codable, Sendable {
    case renamed
    case aboutChanged
    case madePublic
    case madePrivate
    case linkChanged
    case copyingRestricted
    case copyingAllowed
    case reactionsChanged
    case signaturesOn
    case signaturesOff
    case adminAdded
    case adminRemoved
    case banned
    case unbanned
    case appearanceChanged
}

struct ChannelLogEntry: Codable, Sendable, Equatable {
    let date: Date
    let kind: ChannelLogKind
    var detail = ""
}

struct ChannelBannedMember: Codable, Sendable, Equatable {
    let id: String
    let name: String
}

struct ChannelSettings: Codable, Sendable, Equatable {
    var name: String?
    var about: String?
    var link: String?
    var isPrivate: Bool?
    var restrictsCopying: Bool?
    var signsMessages = false
    var reactionRule: ChannelReactionRule?
    var reactionsPerPost: Int?
    var banned: [ChannelBannedMember] = []
    var color: UInt32?
    var wallpaper: ChatWallpaper?
    var log: [ChannelLogEntry] = []
}

extension StorageKey where Value == [String: ChannelSettings] {
    static let channelSettings = StorageKey("channel.settings", default: [:])
}

@MainActor
final class ChannelSettingsStore {
    static let maxReactionsPerPost = 11
    private static let logLimit = 100

    var signatureName: @MainActor () -> String = {
        ProfileFixture.current.name
    }

    private let storage: any KeyValueStore
    private let observers = ObserverList<String>()
    private var all: [String: ChannelSettings]

    init(storage: any KeyValueStore) {
        self.storage = storage
        all = storage.value(for: .channelSettings)
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (String) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    func settings(_ id: String) -> ChannelSettings {
        all[id] ?? ChannelSettings()
    }

    func update(
        _ id: String,
        log kind: ChannelLogKind? = nil,
        detail: String = "",
        change: (inout ChannelSettings) -> Void
    ) {
        var value = settings(id)
        change(&value)
        if let kind {
            value.log.insert(ChannelLogEntry(date: Date(), kind: kind, detail: detail), at: 0)
            value.log = Array(value.log.prefix(Self.logLimit))
        }
        guard value != all[id] else {
            return
        }

        all[id] = value
        observers.notify(id)
        let snapshot = all
        let storage = storage
        Task {
            try? await storage.update(.channelSettings) { stored in
                stored = snapshot
            }
        }
    }

    func link(of id: String) -> String {
        settings(id).link ?? id
    }

    func restrictsCopying(_ id: String) -> Bool {
        settings(id).restrictsCopying ?? ChatFixtures.protectedChannels.contains(id)
    }

    func reactionRule(_ id: String) -> ChannelReactionRule {
        settings(id).reactionRule ?? ChatFixtures.reactionRules[id] ?? .all
    }
}
