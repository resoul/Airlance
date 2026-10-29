import AvatarUI

struct ProfilePeer {
    private static let bios = [
        "Дизайн, Metal і плавні інтерфейси 💧",
        "Фото з вихідних — тут",
        "Пишу код і каву",
        "На звʼязку після 18:00",
    ]

    let peerID: String
    let name: String
    let phone: String
    let username: String
    let bio: String
    let isOnline: Bool

    var avatars: [AvatarDescriptor] {
        PeerAvatars.gallery(id: peerID, name: name)
    }

    init(id: String, chat: ChatSummary?) {
        let seed = id.unicodeScalars.reduce(0) { sum, scalar in
            (sum * 31 + Int(scalar.value)) % 1_000_000
        }
        peerID = id
        name = chat?.name ?? id
        phone = "+380 67 \(100 + seed % 900) \(10 + seed % 90) \(10 + seed / 7 % 90)"
        username = "@\(id)"
        bio = Self.bios[seed % Self.bios.count]
        isOnline = chat?.isOnline ?? false
    }
}
