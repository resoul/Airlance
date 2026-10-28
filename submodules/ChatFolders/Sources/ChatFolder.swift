import Foundation

public enum ChatFolderCategory: Int, CaseIterable, Sendable {
    case contacts
    case nonContacts
    case groups
    case channels
    case bots
}

public enum ChatFolderExclusion: Int, CaseIterable, Sendable {
    case muted
    case read
}

public protocol ChatFolderMember {
    var folderChatID: String { get }
    var folderCategory: ChatFolderCategory { get }
    var isMuted: Bool { get }
    var hasUnread: Bool { get }
}

public struct ChatFolder: Sendable, Equatable, Identifiable {
    public static let colors = 0...6
    public static let maxNameLength = 24

    public let id: String
    public var name: String
    public var emoji: String?
    public var color: Int?
    public var categories: Set<ChatFolderCategory> = []
    public var exclusions: Set<ChatFolderExclusion> = []
    public var included: Set<String> = []
    public var excluded: Set<String> = []

    public init(id: String = UUID().uuidString.lowercased(), name: String) {
        self.id = id
        self.name = name
    }

    public var isEmpty: Bool {
        categories.isEmpty && included.isEmpty
    }

    public func normalized() -> ChatFolder? {
        var folder = self
        folder.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        guard !folder.name.isEmpty else {
            return nil
        }

        if let color, !Self.colors.contains(color) {
            folder.color = nil
        }
        if emoji?.isEmpty == true {
            folder.emoji = nil
        }
        folder.included.subtract(excluded)

        return folder
    }

    public func contains(_ chat: some ChatFolderMember) -> Bool {
        if excluded.contains(chat.folderChatID) {
            return false
        }

        if included.contains(chat.folderChatID) {
            return true
        }

        guard categories.contains(chat.folderCategory) else {
            return false
        }

        if exclusions.contains(.muted), chat.isMuted {
            return false
        }

        return !(exclusions.contains(.read) && !chat.hasUnread)
    }
}

public struct ChatFolderList: Sendable, Equatable {
    public var folders: [ChatFolder]
    public var allChatsPosition: Int

    public init(folders: [ChatFolder] = [], allChatsPosition: Int = 0) {
        self.folders = folders
        self.allChatsPosition = min(max(allChatsPosition, 0), folders.count)
    }

    public static let empty = ChatFolderList()
}
