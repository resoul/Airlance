internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeReader {
    func chat(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .chatopendirect:
            let table: Airlance_Wire_ChatOpenDirect = try checkedRoot(body)

            return .chat(.openDirect(peerSubject: table.peerSubject ?? ""))
        case .chatdata:
            let table: Airlance_Wire_ChatData = try checkedRoot(body)

            return .chat(.chat(Self.serverChat(table)))
        case .messagesend:
            let table: Airlance_Wire_MessageSend = try checkedRoot(body)

            return .chat(.send(chatID: table.chatId ?? "", clientID: table.clientId ?? "", text: table.text ?? ""))
        case .messagedata:
            let table: Airlance_Wire_MessageData = try checkedRoot(body)

            return .chat(.message(Self.serverMessage(table)))
        default:
            return try chatList(kind: kind, body: body)
        }
    }

    private func chatList(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .historyget:
            let table: Airlance_Wire_HistoryGet = try checkedRoot(body)

            return .chat(.historyGet(chatID: table.chatId ?? "", beforeID: table.beforeId, limit: table.limit))
        case .historydata:
            let table: Airlance_Wire_HistoryData = try checkedRoot(body)

            return .chat(.history(table.messages.map(Self.serverMessage)))
        case .chatsget:
            let table: Airlance_Wire_ChatsGet = try checkedRoot(body)

            return .chat(.chatsGet(beforeID: table.beforeId))
        case .chatsdata:
            let table: Airlance_Wire_ChatsData = try checkedRoot(body)

            return .chat(.chats(table.chats.map(Self.serverChat)))
        default:
            return .unsupported(kind: kind)
        }
    }

    private static func serverMessage(_ table: Airlance_Wire_MessageData) -> ServerMessage {
        ServerMessage(
            chatID: table.chatId ?? "",
            messageID: table.messageId,
            sender: table.sender ?? "",
            clientID: table.clientId ?? "",
            text: table.text ?? "",
            sentAtUnixMs: table.sentAtUnixMs
        )
    }

    private static func serverChat(_ table: Airlance_Wire_ChatData) -> ServerChat {
        ServerChat(
            chatID: table.chatId ?? "",
            peer: SearchPerson(
                subject: table.peerSubject ?? "",
                firstName: table.peerFirstName ?? "",
                lastName: table.peerLastName ?? "",
                username: table.peerUsername ?? "",
                photoMediaID: table.peerPhotoMediaId ?? "",
                videoMediaID: table.peerVideoMediaId ?? ""
            ),
            lastMessage: table.lastMessage.map(serverMessage)
        )
    }
}
