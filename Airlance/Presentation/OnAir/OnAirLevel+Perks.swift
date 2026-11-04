extension OnAirLevel {
    static var reactionCount: Int {
        Reactions.quick.count + Reactions.more.count
    }

    var reactionLimit: Int {
        switch self {
        case .none:
            7
        case .bronze:
            14
        case .silver:
            21
        case .gold:
            30
        case .diamond:
            Self.reactionCount
        }
    }

    var allowsAllChannelColors: Bool {
        rawValue >= Self.bronze.rawValue
    }

    var allowsChannelWallpaper: Bool {
        rawValue >= Self.silver.rawValue
    }

    func perks(_ strings: AppStrings) -> [(symbol: String, text: String)] {
        let reactions = self == .diamond
            ? strings.boostLevelsPerkAll
            : strings.boostLevelsPerkReactions(String(reactionLimit))

        var perks = [
            ("face.smiling", reactions),
            (symbol, strings.boostLevelsPerkBadge(title(strings))),
        ]
        if self == .bronze {
            perks.append(("paintpalette", strings.boostLevelsPerkColors))
        }
        if self == .silver {
            perks.append(("photo.on.rectangle", strings.boostLevelsPerkWallpaper))
        }

        return perks
    }
}
