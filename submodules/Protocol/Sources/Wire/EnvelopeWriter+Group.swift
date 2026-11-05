internal import FlatBuffers
internal import ProtocolSchema

extension EnvelopeWriter {
    static func writeGroup(
        _ group: GroupWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch group {
        case .create(let request):
            return (.chatcreate, writeCreate(request, into: &builder))
        case .join(let code):
            let text = builder.create(string: code)

            return (.chatjoin, Airlance_Wire_ChatJoin.createChatJoin(&builder, codeOffset: text))
        case .leave(let chatID):
            let text = builder.create(string: chatID)

            return (.chatleave, Airlance_Wire_ChatLeave.createChatLeave(&builder, chatIdOffset: text))
        case .membersGet(let chatID):
            let text = builder.create(string: chatID)

            return (.chatmembersget, Airlance_Wire_ChatMembersGet.createChatMembersGet(&builder, chatIdOffset: text))
        case .search(let query):
            let text = builder.create(string: query)

            return (.chatsearch, Airlance_Wire_ChatSearch.createChatSearch(&builder, queryOffset: text))
        case .changed:
            return writeChanged(into: &builder)
        default:
            return writeGroupData(group, into: &builder)
        }
    }

    private static func writeGroupData(
        _ group: GroupWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch group {
        case .members(let members):
            return (.chatmembersdata, writeMembers(members, into: &builder))
        case .memberAdd(let chatID, let subject, let role):
            let chat = builder.create(string: chatID)
            let person = builder.create(string: subject)
            let root = Airlance_Wire_ChatMemberAdd.createChatMemberAdd(
                &builder,
                chatIdOffset: chat,
                subjectOffset: person,
                role: role.rawValue
            )

            return (.chatmemberadd, root)
        case .memberRemove(let chatID, let subject):
            let chat = builder.create(string: chatID)
            let person = builder.create(string: subject)
            let root = Airlance_Wire_ChatMemberRemove.createChatMemberRemove(
                &builder,
                chatIdOffset: chat,
                subjectOffset: person
            )

            return (.chatmemberremove, root)
        case .searchResults(let chats):
            let rows = chats.map { chat in
                writeServerChat(chat, into: &builder)
            }
            let vector = builder.createVector(ofOffsets: rows)

            return (.chatsearchdata, Airlance_Wire_ChatSearchData.createChatSearchData(
                &builder,
                chatsVectorOffset: vector
            ))
        default:
            return writeLinkRequest(group, into: &builder)
        }
    }

    private static func writeLinkRequest(
        _ group: GroupWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch group {
        case .muteSet(let chatID, let isMuted):
            let text = builder.create(string: chatID)
            let root = Airlance_Wire_ChatMuteSet.createChatMuteSet(&builder, chatIdOffset: text, isMuted: isMuted)

            return (.chatmuteset, root)
        case .pinSet(let chatID, let isPinned):
            let text = builder.create(string: chatID)
            let root = Airlance_Wire_ChatPinSet.createChatPinSet(&builder, chatIdOffset: text, isPinned: isPinned)

            return (.chatpinset, root)
        case .resolve(let code):
            let text = builder.create(string: code)

            return (.chatresolve, Airlance_Wire_ChatResolve.createChatResolve(&builder, codeOffset: text))
        case .inviteReset(let chatID):
            let text = builder.create(string: chatID)

            return (.chatinvitereset, Airlance_Wire_ChatInviteReset.createChatInviteReset(&builder, chatIdOffset: text))
        case .userResolve(let username):
            let text = builder.create(string: username)

            return (.userresolve, Airlance_Wire_UserResolve.createUserResolve(&builder, usernameOffset: text))
        default:
            return writeChanged(into: &builder)
        }
    }

    private static func writeChanged(into builder: inout FlatBufferBuilder) -> (Airlance_Wire_MessageKind, Offset) {
        let start = Airlance_Wire_ChatsChanged.startChatsChanged(&builder)

        return (.chatschanged, Airlance_Wire_ChatsChanged.endChatsChanged(&builder, start: start))
    }

    private static func writeCreate(_ request: ChatCreateRequest, into builder: inout FlatBufferBuilder) -> Offset {
        let client = builder.create(string: request.clientID)
        let title = builder.create(string: request.title)
        let about = builder.create(string: request.about)
        let link = builder.create(string: request.link)
        let people = request.members.map { member in
            builder.create(string: member)
        }
        let members = builder.createVector(ofOffsets: people)

        return Airlance_Wire_ChatCreate.createChatCreate(
            &builder,
            clientIdOffset: client,
            kind: request.kind.rawValue,
            titleOffset: title,
            aboutOffset: about,
            linkOffset: link,
            membersVectorOffset: members
        )
    }

    private static func writeMembers(_ members: [ServerChatMember], into builder: inout FlatBufferBuilder) -> Offset {
        let rows = members.map { member in
            let subject = builder.create(string: member.person.subject)
            let first = builder.create(string: member.person.firstName)
            let last = builder.create(string: member.person.lastName)
            let username = builder.create(string: member.person.username)
            let photo = builder.create(string: member.person.photoMediaID)
            let video = builder.create(string: member.person.videoMediaID)

            return Airlance_Wire_ChatMemberData.createChatMemberData(
                &builder,
                subjectOffset: subject,
                firstNameOffset: first,
                lastNameOffset: last,
                usernameOffset: username,
                photoMediaIdOffset: photo,
                videoMediaIdOffset: video,
                role: member.role.rawValue
            )
        }
        let vector = builder.createVector(ofOffsets: rows)

        return Airlance_Wire_ChatMembersData.createChatMembersData(&builder, membersVectorOffset: vector)
    }
}
