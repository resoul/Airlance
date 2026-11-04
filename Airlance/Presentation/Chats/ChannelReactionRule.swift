enum ChannelReactionRule: Codable, Sendable, Equatable {
    case all
    case some([String])
    case none

    var allowed: [String]? {
        switch self {
        case .all:
            nil
        case .some(let emojis):
            emojis
        case .none:
            []
        }
    }

    func allows(_ emoji: String) -> Bool {
        allowed?.contains(emoji) ?? true
    }

    func doubleTapEmoji(default emoji: String) -> String? {
        allows(emoji) ? emoji : allowed?.first
    }
}
