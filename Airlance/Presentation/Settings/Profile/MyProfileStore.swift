import AvatarUI
import DatabaseAPI
import Foundation
import MediaStore
import Observers

enum BirthdayVisibility: String, Codable, Sendable, CaseIterable {
    case everyone
    case contacts
    case nobody
}

struct ProfileBirthday: Codable, Sendable, Equatable {
    let year: Int
    let month: Int
    let day: Int
}

struct MyProfile: Codable, Sendable, Equatable {
    static let bioLimit = 70
    static let usernameRange = 5...32

    var firstName: String
    var lastName = ""
    var bio = ""
    var username: String
    var phone: String
    var birthday: ProfileBirthday?
    var birthdayVisibility = BirthdayVisibility.nobody
    var photo: LocalMedia?

    var fullName: String {
        let parts = [firstName, lastName].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " ")
    }

    var contactLine: String {
        let parts = [phone, username.isEmpty ? "" : "@\(username)"].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " · ")
    }

    static func isValidUsername(_ username: String) -> Bool {
        guard usernameRange.contains(username.count), username.first?.isLetter == true, username.last != "_" else {
            return false
        }

        return username.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "_")
        }
    }

    static var initial: MyProfile {
        let fixture = ProfileFixture.current
        let parts = fixture.name.split(separator: " ", maxSplits: 1).map(String.init)

        return MyProfile(
            firstName: parts.first ?? "",
            lastName: parts.count > 1 ? parts[1] : "",
            username: String(fixture.username.drop { character in
                character == "@"
            }),
            phone: fixture.phone
        )
    }
}

extension StorageKey where Value == MyProfile {
    static let myProfile = StorageKey("profile.me", default: .initial)
}

@MainActor
final class MyProfileStore {
    let media: MediaStore

    private(set) var profile: MyProfile
    private let storage: any KeyValueStore
    private let observers = ObserverList<MyProfile>()

    init(storage: any KeyValueStore, media: MediaStore) {
        self.storage = storage
        self.media = media
        profile = storage.value(for: .myProfile)
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (MyProfile) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    func update(_ next: MyProfile) {
        guard next != profile else {
            return
        }

        if let old = profile.photo, old != next.photo {
            media.remove(old)
        }
        profile = next
        observers.notify(next)
        let storage = storage
        Task {
            try? await storage.update(.myProfile) { value in
                value = next
            }
        }
    }

    func avatar(for profile: MyProfile) -> AvatarDescriptor {
        guard let photo = profile.photo else {
            return PeerAvatars.descriptor(id: "me", name: profile.fullName)
        }

        let url = MediaStore.url(for: photo)
        let image = AvatarImage(key: "me:\(photo.name)") {
            try? Data(contentsOf: url)
        }

        return AvatarDescriptor(
            id: "me",
            initials: AvatarDescriptor.initials(from: profile.fullName),
            image: image
        )
    }
}
