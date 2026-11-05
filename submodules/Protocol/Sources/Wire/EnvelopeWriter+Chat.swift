internal import FlatBuffers
internal import ProtocolSchema

extension EnvelopeWriter {
    static func writeChat(
        _ chat: ChatWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch chat {
        case .openDirect(let peerSubject):
            let text = builder.create(string: peerSubject)
            let root = Airlance_Wire_ChatOpenDirect.createChatOpenDirect(&builder, peerSubjectOffset: text)

            return (.chatopendirect, root)
        case .chat(let chat):
            return (.chatdata, writeServerChat(chat, into: &builder))
        case .send(let chatID, let clientID, let text):
            return (.messagesend, writeSend(chatID: chatID, clientID: clientID, text: text, into: &builder))
        case .message(let message):
            return (.messagedata, writeServerMessage(message, into: &builder))
        case .historyGet(let chatID, let beforeID, let limit):
            let chat = builder.create(string: chatID)
            let root = Airlance_Wire_HistoryGet.createHistoryGet(
                &builder,
                chatIdOffset: chat,
                beforeId: beforeID,
                limit: limit
            )

            return (.historyget, root)
        case .history(let messages):
            return (.historydata, writeHistory(messages, into: &builder))
        case .chatsGet(let beforeID):
            return (.chatsget, Airlance_Wire_ChatsGet.createChatsGet(&builder, beforeId: beforeID))
        case .chats(let chats):
            return (.chatsdata, writeChats(chats, into: &builder))
        }
    }

    private static func writeSend(
        chatID: String,
        clientID: String,
        text: String,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let chat = builder.create(string: chatID)
        let client = builder.create(string: clientID)
        let body = builder.create(string: text)

        return Airlance_Wire_MessageSend.createMessageSend(
            &builder,
            chatIdOffset: chat,
            clientIdOffset: client,
            textOffset: body
        )
    }

    private static func writeHistory(_ messages: [ServerMessage], into builder: inout FlatBufferBuilder) -> Offset {
        let rows = messages.map { message in
            writeServerMessage(message, into: &builder)
        }
        let vector = builder.createVector(ofOffsets: rows)

        return Airlance_Wire_HistoryData.createHistoryData(&builder, messagesVectorOffset: vector)
    }

    private static func writeChats(_ chats: [ServerChat], into builder: inout FlatBufferBuilder) -> Offset {
        let rows = chats.map { chat in
            writeServerChat(chat, into: &builder)
        }
        let vector = builder.createVector(ofOffsets: rows)

        return Airlance_Wire_ChatsData.createChatsData(&builder, chatsVectorOffset: vector)
    }

    private static func writeServerMessage(_ message: ServerMessage, into builder: inout FlatBufferBuilder) -> Offset {
        let chat = builder.create(string: message.chatID)
        let sender = builder.create(string: message.sender)
        let client = builder.create(string: message.clientID)
        let text = builder.create(string: message.text)

        return Airlance_Wire_MessageData.createMessageData(
            &builder,
            chatIdOffset: chat,
            messageId: message.messageID,
            senderOffset: sender,
            clientIdOffset: client,
            textOffset: text,
            sentAtUnixMs: message.sentAtUnixMs
        )
    }

    private static func writeServerChat(_ chat: ServerChat, into builder: inout FlatBufferBuilder) -> Offset {
        let last = chat.lastMessage.map { message in
            writeServerMessage(message, into: &builder)
        } ?? Offset()
        let id = builder.create(string: chat.chatID)
        let subject = builder.create(string: chat.peer.subject)
        let first = builder.create(string: chat.peer.firstName)
        let lastName = builder.create(string: chat.peer.lastName)
        let username = builder.create(string: chat.peer.username)

        let photo = builder.create(string: chat.peer.photoMediaID)
        let video = builder.create(string: chat.peer.videoMediaID)

        return Airlance_Wire_ChatData.createChatData(
            &builder,
            chatIdOffset: id,
            peerSubjectOffset: subject,
            peerFirstNameOffset: first,
            peerLastNameOffset: lastName,
            peerUsernameOffset: username,
            lastMessageOffset: last,
            peerPhotoMediaIdOffset: photo,
            peerVideoMediaIdOffset: video
        )
    }
}
