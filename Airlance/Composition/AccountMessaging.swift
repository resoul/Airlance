import ChatStorage
import Foundation
import os
import Protocol
import ServerConnection

enum AccountMessagingError: Error {
    case refused
}

@MainActor
final class AccountMessaging {
    private static let logger = Logger(subsystem: "Airlance", category: "Messaging")

    let me: String

    private let connection: ServerConnection
    private let storage: ChatStorage
    private let isViewed: @MainActor (String) -> Bool
    private var sending: Set<String> = []

    init(
        connection: ServerConnection,
        storage: ChatStorage,
        me: String,
        isViewed: @escaping @MainActor (String) -> Bool
    ) {
        self.connection = connection
        self.storage = storage
        self.me = me
        self.isViewed = isViewed
    }

    func applyUpdate(_ message: ServerMessage, seq: UInt64) async throws {
        let countsUnread = message.sender != me && !isViewed(message.chatID)
        let hasPeer = try await storage.applyReceived(Self.stored(message), seq: seq, countsUnread: countsUnread)
        if !hasPeer {
            await refreshChats()
        }
    }

    func refreshChats() async {
        do {
            guard case .chat(.chats(let chats)) = try await connection.request(.chat(.chatsGet(beforeID: 0))) else {
                return
            }

            for chat in chats {
                try await save(chat)
            }
        } catch {
            Self.logger.debug("Can't load the chats: \(String(describing: error))")
        }
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

        let request = ChatWireMessage.send(chatID: message.chatID, clientID: message.clientID, text: message.text)
        Task {
            await self.deliver(message, request: request)
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

        try await save(chat)

        return chat.chatID
    }

    private func deliver(_ message: StoredMessage, request: ChatWireMessage) async {
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

    private func save(_ chat: ServerChat) async throws {
        let peer = StoredPeer(
            subject: chat.peer.subject,
            firstName: chat.peer.firstName,
            lastName: chat.peer.lastName,
            username: chat.peer.username,
            photoMediaID: chat.peer.photoMediaID,
            videoMediaID: chat.peer.videoMediaID
        )
        try await storage.saveChat(id: chat.chatID, peer: peer)
    }

    private static func stored(_ message: ServerMessage) -> StoredMessage {
        StoredMessage(
            chatID: message.chatID,
            sender: message.sender,
            clientID: message.clientID,
            messageID: message.messageID,
            text: message.text,
            sentAtMs: message.sentAtUnixMs,
            state: .sent
        )
    }
}
