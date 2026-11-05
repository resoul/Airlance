import AvatarUI
import Protocol

@MainActor
struct ProfilePeer {
    private static let bios = [
        "Дизайн, Metal і плавні інтерфейси 💧",
        "Фото з вихідних — тут",
        "Пишу код і каву",
        "На звʼязку після 18:00",
    ]

    let peerID: String
    let name: String
    var phone: String
    var username: String
    var bio: String
    let isOnline: Bool

    var avatars: [AvatarDescriptor] {
        PeerAvatars.gallery(id: peerID, name: name)
    }

    init(id: String, chat: ChatSummary?) {
        let seed = id.unicodeScalars.reduce(0) { sum, scalar in
            (sum * 31 + Int(scalar.value)) % 1_000_000
        }
        peerID = id
        let member = ChatChannelFixtures.commenters.first { person in
            person.id == id
        }
        name = chat?.name ?? member?.name ?? id
        isOnline = chat?.isOnline ?? false
        if let server = PeerAvatars.server(id) {
            phone = ""
            username = Self.handle(server.username)
            bio = ""

            return
        }

        phone = "+380 67 \(100 + seed % 900) \(10 + seed % 90) \(10 + seed / 7 % 90)"
        username = "@\(id)"
        bio = Self.bios[seed % Self.bios.count]
    }

    mutating func apply(_ fields: ProfileFields) {
        username = Self.handle(fields.username)
        bio = fields.bio
    }

    private static func handle(_ username: String) -> String {
        username.isEmpty ? "" : "@\(username)"
    }
}
