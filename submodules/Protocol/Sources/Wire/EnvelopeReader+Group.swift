internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeReader {
    func group(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .chatcreate:
            let table: Airlance_Wire_ChatCreate = try checkedRoot(body)

            return .group(.create(ChatCreateRequest(
                clientID: table.clientId ?? "",
                kind: ServerChatKind(rawValue: table.kind) ?? .direct,
                title: table.title ?? "",
                about: table.about ?? "",
                link: table.link ?? "",
                members: table.members.compactMap(\.self)
            )))
        case .chatjoin:
            let table: Airlance_Wire_ChatJoin = try checkedRoot(body)

            return .group(.join(code: table.code ?? ""))
        case .chatleave:
            let table: Airlance_Wire_ChatLeave = try checkedRoot(body)

            return .group(.leave(chatID: table.chatId ?? ""))
        case .chatmembersget:
            let table: Airlance_Wire_ChatMembersGet = try checkedRoot(body)

            return .group(.membersGet(chatID: table.chatId ?? ""))
        case .chatmembersdata:
            let table: Airlance_Wire_ChatMembersData = try checkedRoot(body)

            return .group(.members(table.members.map(Self.serverMember)))
        default:
            return try groupChange(kind: kind, body: body)
        }
    }

    private func groupChange(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .chatmemberadd:
            let table: Airlance_Wire_ChatMemberAdd = try checkedRoot(body)

            return .group(.memberAdd(
                chatID: table.chatId ?? "",
                subject: table.subject ?? "",
                role: ServerChatRole(rawValue: table.role) ?? .member
            ))
        case .chatmemberremove:
            let table: Airlance_Wire_ChatMemberRemove = try checkedRoot(body)

            return .group(.memberRemove(chatID: table.chatId ?? "", subject: table.subject ?? ""))
        case .chatsearch:
            let table: Airlance_Wire_ChatSearch = try checkedRoot(body)

            return .group(.search(query: table.query ?? ""))
        case .chatsearchdata:
            let table: Airlance_Wire_ChatSearchData = try checkedRoot(body)

            return .group(.searchResults(table.chats.map(Self.serverChat)))
        case .chatmuteset:
            let table: Airlance_Wire_ChatMuteSet = try checkedRoot(body)

            return .group(.muteSet(chatID: table.chatId ?? "", isMuted: table.isMuted))
        case .chatpinset:
            let table: Airlance_Wire_ChatPinSet = try checkedRoot(body)

            return .group(.pinSet(chatID: table.chatId ?? "", isPinned: table.isPinned))
        case .chatresolve:
            let table: Airlance_Wire_ChatResolve = try checkedRoot(body)

            return .group(.resolve(code: table.code ?? ""))
        case .chatinvitereset:
            let table: Airlance_Wire_ChatInviteReset = try checkedRoot(body)

            return .group(.inviteReset(chatID: table.chatId ?? ""))
        case .userresolve:
            let table: Airlance_Wire_UserResolve = try checkedRoot(body)

            return .group(.userResolve(username: table.username ?? ""))
        case .chatschanged:
            let _: Airlance_Wire_ChatsChanged = try checkedRoot(body)

            return .group(.changed)
        default:
            return .unsupported(kind: kind)
        }
    }

    private static func serverMember(_ table: Airlance_Wire_ChatMemberData) -> ServerChatMember {
        ServerChatMember(
            person: SearchPerson(
                subject: table.subject ?? "",
                firstName: table.firstName ?? "",
                lastName: table.lastName ?? "",
                username: table.username ?? "",
                photoMediaID: table.photoMediaId ?? "",
                videoMediaID: table.videoMediaId ?? ""
            ),
            role: ServerChatRole(rawValue: table.role) ?? .member
        )
    }
}
