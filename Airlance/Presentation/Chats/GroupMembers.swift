import ChatHistory
import Foundation
import Observers
import Protocol

enum GroupRole: Int, Sendable, Comparable {
    case owner
    case admin
    case member

    static func < (lhs: GroupRole, rhs: GroupRole) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum GroupRight: String, CaseIterable, Sendable {
    case sendMessages
    case sendMedia
    case addMembers
    case pinMessages
    case changeInfo
    case deleteMessages
    case banUsers
    case addAdmins

    static let memberRights: [GroupRight] = [.sendMessages, .sendMedia, .addMembers, .pinMessages, .changeInfo]
    static let adminRights: [GroupRight] = [
        .changeInfo, .deleteMessages, .banUsers, .pinMessages, .addMembers, .addAdmins,
    ]
    static let defaultAdmin: Set<GroupRight> = [.changeInfo, .deleteMessages, .banUsers, .pinMessages, .addMembers]
}

struct GroupMember: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    var role: GroupRole
    var rights: Set<GroupRight>
    let isOnline: Bool
}

extension GroupMember {
    @MainActor
    init(server: ServerChatMember, me: String) {
        let parts = [server.person.firstName, server.person.lastName].filter { part in
            !part.isEmpty
        }
        let role: GroupRole
        switch server.role {
        case .owner:
            role = .owner
        case .admin:
            role = .admin
        case .member:
            role = .member
        }
        self.init(
            id: server.person.subject == me ? GroupMembersStore.me.id : server.person.subject,
            name: parts.joined(separator: " "),
            role: role,
            rights: [],
            isOnline: false
        )
    }
}

struct GroupEvent: Sendable {
    let chatID: String
}

@MainActor
final class GroupMembersStore {
    static let me = MessageCommenter(id: "me", name: "Ти")
    private static let ownGroups: Set<String> = ChatFixtures.ownChannels.union(["team", "family"])

    private var members: [String: [GroupMember]] = [:]
    private var permissions: [String: Set<GroupRight>] = [:]
    private let observers = ObserverList<GroupEvent>()
    var serverLoader: (@MainActor (String) async -> [GroupMember]?)?

    func observe(_ onChange: @escaping @MainActor @Sendable (GroupEvent) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    func members(in chatID: String) -> [GroupMember] {
        if let list = members[chatID] {
            return list
        }

        guard serverLoader == nil else {
            reload(chatID)

            return []
        }

        let list = Self.fixture(chatID)
        members[chatID] = list

        return list
    }

    func reload(_ chatID: String) {
        guard let serverLoader else {
            return
        }

        if members[chatID] == nil {
            members[chatID] = []
        }
        Task { [weak self] in
            guard let list = await serverLoader(chatID), let self else {
                return
            }

            self.members[chatID] = Self.sorted(list)
            self.observers.notify(GroupEvent(chatID: chatID))
        }
    }

    func myRole(in chatID: String) -> GroupRole {
        guard serverLoader == nil else {
            return .member
        }

        return members(in: chatID).first { member in
            member.id == Self.me.id
        }?.role ?? .member
    }

    func permissions(in chatID: String) -> Set<GroupRight> {
        permissions[chatID] ?? Set(GroupRight.memberRights)
    }

    func setPermissions(_ rights: Set<GroupRight>, in chatID: String) {
        permissions[chatID] = rights
        observers.notify(GroupEvent(chatID: chatID))
    }

    func promote(_ memberID: String, rights: Set<GroupRight>, in chatID: String) {
        update(memberID, in: chatID) { member in
            member.role = .admin
            member.rights = rights
        }
    }

    func demote(_ memberID: String, in chatID: String) {
        update(memberID, in: chatID) { member in
            member.role = .member
            member.rights = []
        }
    }

    func remove(_ memberID: String, from chatID: String) {
        members[chatID] = members(in: chatID).filter { member in
            member.id != memberID
        }
        observers.notify(GroupEvent(chatID: chatID))
    }

    func add(_ member: GroupMember, to chatID: String) {
        members[chatID] = Self.sorted(members(in: chatID) + [member])
        observers.notify(GroupEvent(chatID: chatID))
    }

    private func update(_ memberID: String, in chatID: String, change: (inout GroupMember) -> Void) {
        var list = members(in: chatID)
        guard let index = list.firstIndex(where: { member in
            member.id == memberID
        }) else {
            return
        }

        change(&list[index])
        members[chatID] = Self.sorted(list)
        observers.notify(GroupEvent(chatID: chatID))
    }

    private static func fixture(_ chatID: String) -> [GroupMember] {
        let isOwn = ownGroups.contains(chatID)
        let seed = chatID.unicodeScalars.reduce(0) { sum, scalar in
            (sum * 31 + Int(scalar.value)) % 10_000
        }
        var list = [
            GroupMember(
                id: me.id,
                name: me.name,
                role: isOwn ? .owner : .member,
                rights: isOwn ? Set(GroupRight.adminRights) : [],
                isOnline: true
            ),
        ]
        for (index, person) in ChatChannelFixtures.commenters.enumerated() {
            let role: GroupRole = !isOwn && index == seed % 3 ? .owner : (index % 4 == 1 ? .admin : .member)
            list.append(GroupMember(
                id: person.id,
                name: person.name,
                role: role,
                rights: role == .member ? [] : GroupRight.defaultAdmin,
                isOnline: (seed + index) % 3 == 0
            ))
        }

        return sorted(list)
    }

    private static func sorted(_ list: [GroupMember]) -> [GroupMember] {
        list.sorted { lhs, rhs in
            (lhs.role, lhs.isOnline ? 0 : 1, lhs.name) < (rhs.role, rhs.isOnline ? 0 : 1, rhs.name)
        }
    }
}
