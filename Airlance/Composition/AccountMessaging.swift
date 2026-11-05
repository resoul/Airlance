import ChatStorage
import Foundation
import os
import Protocol
import ServerConnection

enum AccountMessagingError: Error {
    case refused
    case missingFile
}

@MainActor
final class AccountMessaging {
    private static let logger = Logger(subsystem: "Airlance", category: "Messaging")
    private static let refreshDelay: Duration = .milliseconds(400)
    private static let historyPage: Int32 = 100
    private static let raceMargin: Int64 = 60_000

    let me: String

    let connection: ServerConnection
    let storage: ChatStorage
    private let isViewed: @MainActor (String) -> Bool
    private let username: @MainActor () -> String
    private let uploader: ServerAttachmentUploader
    private var sending: Set<String> = []
    private var refreshing: Task<Void, Never>?

    init(
        connection: ServerConnection,
        storage: ChatStorage,
        me: String,
        account: String,
        files: ProfileMediaFiles,
        username: @escaping @MainActor () -> String,
        isViewed: @escaping @MainActor (String) -> Bool
    ) {
        uploader = ServerAttachmentUploader(files: files, storage: storage, account: account)
        self.username = username
        self.connection = connection
        self.storage = storage
        self.me = me
        self.isViewed = isViewed
    }

    func applyUpdate(_ message: ServerMessage, seq: UInt64) async throws {
        let countsUnread = message.sender != me && !isViewed(message.chatID)
        let isKnown = try await storage.applyReceived(
            Self.stored(message),
            seq: seq,
            countsUnread: countsUnread,
            isMention: countsUnread && mentionsMe(message.text)
        )
        if !isKnown {
            await refreshChats()
        }
    }

    private func mentionsMe(_ text: String) -> Bool {
        let name = username()

        return !name.isEmpty && text.range(of: "@\(name)", options: .caseInsensitive) != nil
    }

    func scheduleRefresh() {
        refreshing?.cancel()
        refreshing = Task { [weak self] in
            try? await Task.sleep(for: Self.refreshDelay)
            guard !Task.isCancelled else {
                return
            }

            await self?.refreshChats()
        }
    }

    func refreshChats() async {
        let started = Int64(Date().timeIntervalSince1970 * 1000)
        do {
            let chats = try await allChats()
            for chat in chats {
                try await save(chat)
                try await loadHistoryOnce(of: chat)
            }
            let keeping = Set(chats.map(\.chatID))
            try await storage.removeChats(missingFrom: keeping, before: started - Self.raceMargin)
        } catch {
            Self.logger.debug("Can't load the chats: \(String(describing: error))")
        }
    }

    private func allChats() async throws -> [ServerChat] {
        var found: [ServerChat] = []
        var before: Int64 = 0
        while true {
            let reply = try await connection.request(.chat(.chatsGet(beforeID: before)))
            guard case .chat(.chats(let page)) = reply else {
                throw AccountMessagingError.refused
            }

            found += page
            guard let last = page.last?.lastMessage?.messageID, !page.isEmpty else {
                return found
            }

            before = last
        }
    }

    private func loadHistoryOnce(of chat: ServerChat) async throws {
        guard chat.details.kind != .direct, chat.lastMessage != nil else {
            return
        }

        guard try await !storage.isHistoryLoaded(chat.chatID) else {
            return
        }

        for message in try await history(of: chat.chatID) {
            _ = try await storage.applyReceived(Self.stored(message), seq: nil, countsUnread: false)
        }
        try await storage.markHistoryLoaded(chat.chatID)
    }

    private func history(of chatID: String) async throws -> [ServerMessage] {
        let request = ChatWireMessage.historyGet(chatID: chatID, beforeID: 0, limit: Self.historyPage)
        guard case .chat(.history(let messages)) = try await connection.request(.chat(request)) else {
            throw AccountMessagingError.refused
        }

        return messages.reversed()
    }

    func previewHistory(_ chatID: String) async -> [StoredMessage] {
        (try? await history(of: chatID))?.map(Self.stored) ?? []
    }

    func searchChats(_ query: String) async throws -> [ServerChat] {
        let reply = try await connection.request(.group(.search(query: query)))
        guard case .group(.searchResults(let chats)) = reply else {
            throw AccountMessagingError.refused
        }

        return chats
    }

    func join(code: String) async throws {
        guard case .chat(.chat(let chat)) = try await connection.request(.group(.join(code: code))) else {
            throw AccountMessagingError.refused
        }

        try await save(chat)
        try await loadHistoryOnce(of: chat)
    }

    func leave(_ chatID: String) async throws {
        guard case .group(.changed) = try await connection.request(.group(.leave(chatID: chatID))) else {
            throw AccountMessagingError.refused
        }

        try await storage.removeChat(chatID)
    }

    func members(of chatID: String) async throws -> [ServerChatMember] {
        let reply = try await connection.request(.group(.membersGet(chatID: chatID)))
        guard case .group(.members(let members)) = reply else {
            throw AccountMessagingError.refused
        }

        return members
    }

    func flushPending() async {
        do {
            for message in try await storage.pending() {
                send(message)
            }
        } catch {
            Self.logger.error("Can't read the unsent messages: \(String(describing: error))")
        }
    }

    func send(_ message: StoredMessage) {
        guard sending.insert(message.clientID).inserted else {
            return
        }

        Task {
            await self.deliver(message)
            self.sending.remove(message.clientID)
        }
    }

    func search(_ query: String) async throws -> [SearchPerson] {
        guard case .search(.results(let people)) = try await connection.request(.search(.query(query))) else {
            throw AccountMessagingError.refused
        }

        return people
    }

    func publicProfile(_ subject: String) async -> ProfileData? {
        let request = ProtocolMessage.search(.publicProfileGet(subject: subject))
        guard case .profileData(let data)? = try? await connection.request(request) else {
            return nil
        }

        return data
    }

    func openDirect(with person: SearchPerson) async throws -> String {
        let reply = try await connection.request(.chat(.openDirect(peerSubject: person.subject)))
        guard case .chat(.chat(let chat)) = reply else {
            throw AccountMessagingError.refused
        }

        try await save(chat, keepsPin: true)

        return chat.chatID
    }

    private func deliver(_ source: StoredMessage) async {
        let message: StoredMessage
        do {
            message = try await uploader.uploaded(source)
        } catch AccountMessagingError.missingFile {
            try? await storage.setFailed(source)

            return
        } catch {
            Self.logger.debug("A file waits for the connection: \(String(describing: error))")

            return
        }

        let request = ChatWireMessage.send(
            chatID: message.chatID,
            clientID: message.clientID,
            text: message.text,
            forwardName: message.forwardName,
            attachments: message.attachments.map(ServerAttachment.init(stored:))
        )
        do {
            switch try await connection.request(.chat(request)) {
            case .chat(.message(let stored)):
                _ = try await storage.applyReceived(Self.stored(stored), seq: nil, countsUnread: false)
            case .error(let error):
                Self.logger.error("A message was refused: \(error.message)")
                try await storage.setFailed(message)
            default:
                try await storage.setFailed(message)
            }
        } catch {
            Self.logger.debug("A message waits for the connection: \(String(describing: error))")
        }
    }

    func save(_ chat: ServerChat, keepsPin: Bool = false) async throws {
        let peer = StoredPeer(
            subject: chat.peer.subject,
            firstName: chat.peer.firstName,
            lastName: chat.peer.lastName,
            username: chat.peer.username,
            photoMediaID: chat.peer.photoMediaID,
            videoMediaID: chat.peer.videoMediaID
        )
        let details = StoredChatDetails(
            kind: StoredChatKind(rawValue: Int(chat.details.kind.rawValue)) ?? .direct,
            title: chat.details.title,
            about: chat.details.about,
            link: chat.details.link,
            inviteToken: chat.details.inviteToken,
            memberCount: Int(chat.details.memberCount),
            role: Int(chat.details.role.rawValue),
            isPinned: chat.details.isPinned
        )
        try await storage.saveChat(id: chat.chatID, peer: peer, details: details, keepsPin: keepsPin)
    }

    private static func stored(_ message: ServerMessage) -> StoredMessage {
        StoredMessage(
            chatID: message.chatID,
            sender: message.sender,
            clientID: message.clientID,
            messageID: message.messageID,
            text: message.text,
            sentAtMs: message.sentAtUnixMs,
            state: .sent,
            author: StoredAuthor(
                firstName: message.author.firstName,
                lastName: message.author.lastName,
                photoMediaID: message.author.photoMediaID,
                videoMediaID: message.author.videoMediaID,
                agentName: message.author.agentName
            ),
            attachments: message.attachments.map(StoredAttachment.init(server:)),
            forwardName: message.forwardName
        )
    }
}
