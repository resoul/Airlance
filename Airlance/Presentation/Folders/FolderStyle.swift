import ChatFolders
import UIKit

struct FoldersDependencies {
    let presentationContext: PresentationContext
    let chatFolders: ChatFolderStore
    let chatsStore: ChatsStore
}

enum FolderStyle {
    static let colors: [UIColor] = [
        UIColor(red: 0.89, green: 0.33, blue: 0.29, alpha: 1),
        UIColor(red: 0.91, green: 0.53, blue: 0.20, alpha: 1),
        UIColor(red: 0.62, green: 0.40, blue: 0.87, alpha: 1),
        UIColor(red: 0.30, green: 0.72, blue: 0.27, alpha: 1),
        UIColor(red: 0.18, green: 0.67, blue: 0.78, alpha: 1),
        UIColor(red: 0.21, green: 0.55, blue: 0.89, alpha: 1),
        UIColor(red: 0.85, green: 0.33, blue: 0.62, alpha: 1),
    ]
    static let colorOrder = [5, 3, 1, 0, 2, 4, 6]
    static let emoji = [
        "💬", "👤", "👥", "📢", "🤖", "⭐️", "❤️", "🔥", "✅", "📌", "💼", "🏠",
        "🎓", "🎮", "🎵", "📚", "✈️", "🛒", "💰", "🍕", "⚽️", "🐶", "🌍", "🎉",
    ]

    static func color(_ index: Int?) -> UIColor? {
        index.flatMap { index in
            colors.indices.contains(index) ? colors[index] : nil
        }
    }

    static func symbol(for category: ChatFolderCategory) -> String {
        switch category {
        case .contacts:
            "person.fill"
        case .nonContacts:
            "person.fill.questionmark"
        case .groups:
            "person.2.fill"
        case .channels:
            "megaphone.fill"
        case .bots:
            "cpu"
        }
    }

    static func symbol(for exclusion: ChatFolderExclusion) -> String {
        switch exclusion {
        case .muted:
            "bell.slash.fill"
        case .read:
            "checkmark.message.fill"
        }
    }

    static func title(_ folder: ChatFolder) -> String {
        folder.emoji.map { emoji in
            "\(emoji) \(folder.name)"
        } ?? folder.name
    }
}
