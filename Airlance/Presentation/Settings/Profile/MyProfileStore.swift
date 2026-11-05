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

struct MyProfilePhoto: Codable, Sendable, Equatable {
    var photo: LocalMedia?
    var video: LocalMedia?
    var photoMediaID: String?
    var videoMediaID: String?
    var addedAtUnix: Int64 = 0
}

struct MyProfile: Codable, Sendable, Equatable {
    static let bioLimit = 70
    static let phoneLimit = 32
    static let usernameRange = 5...32

    var firstName: String
    var lastName = ""
    var bio = ""
    var username: String
    var phone: String
    var birthday: ProfileBirthday?
    var birthdayVisibility = BirthdayVisibility.nobody
    var photoItems: [MyProfilePhoto]?
    var photoRemovals: [String]?
    var mainPhotoID: String?

    var photos: [MyProfilePhoto] {
        get {
            photoItems ?? []
        }
        set {
            photoItems = newValue
        }
    }

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

    static let blank = MyProfile(firstName: "", username: "", phone: "")
}

extension StorageKey where Value == MyProfile {
    static let myProfile = StorageKey("profile.me", default: .initial)
}

@MainActor
final class MyProfileStore {
    let media: MediaStore
    var files: ProfileMediaFiles?

    private(set) var profile: MyProfile
    private let usesDemoProfile: Bool
    private let storage: any KeyValueStore
    private let observers = ObserverList<MyProfile>()

    init(storage: any KeyValueStore, media: MediaStore, usesDemoProfile: Bool) {
        self.storage = storage
        self.media = media
        self.usesDemoProfile = usesDemoProfile
        let stored = storage.value(for: .myProfile)
        profile = !usesDemoProfile && stored == .initial ? .blank : stored
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (MyProfile) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    func update(_ next: MyProfile) {
        guard next != profile else {
            return
        }

        removeLostFiles(next)
        profile = next
        observers.notify(next)
        let storage = storage
        Task {
            try? await storage.update(.myProfile) { value in
                value = next
            }
        }
    }

    func addPhoto(photo: LocalMedia, video: LocalMedia?) {
        var next = profile
        let added = Int64(Date().timeIntervalSince1970)
        next.photos.insert(MyProfilePhoto(photo: photo, video: video, addedAtUnix: added), at: 0)
        update(next)
    }

    func removePhoto(_ item: MyProfilePhoto) {
        var next = profile
        next.photos.removeAll { candidate in
            candidate == item
        }
        if let id = item.photoMediaID {
            next.photoRemovals = (next.photoRemovals ?? []) + [id]
            if next.mainPhotoID == id {
                next.mainPhotoID = nil
            }
        }
        update(next)
    }

    func makeMain(_ item: MyProfilePhoto) {
        var next = profile
        guard let position = next.photos.firstIndex(of: item) else {
            return
        }

        next.photos.remove(at: position)
        next.photos.insert(item, at: 0)
        next.mainPhotoID = item.photoMediaID
        update(next)
    }

    func gallery(for profile: MyProfile) -> [AvatarDescriptor] {
        if !profile.photos.isEmpty {
            return profile.photos.enumerated().map { index, item in
                descriptor(item, id: index == 0 ? "me" : "me.\(index)", name: profile.fullName)
            }
        }

        return usesDemoProfile ? PeerAvatars.gallery(id: "me", name: profile.fullName) : []
    }

    func avatar(for profile: MyProfile) -> AvatarDescriptor {
        if let first = profile.photos.first {
            return descriptor(first, id: "me", name: profile.fullName)
        }

        let letters = AvatarDescriptor(id: "me", initials: AvatarDescriptor.initials(from: profile.fullName))

        return usesDemoProfile ? PeerAvatars.descriptor(id: "me", name: profile.fullName) : letters
    }

    private func descriptor(_ item: MyProfilePhoto, id: String, name: String) -> AvatarDescriptor {
        let initials = AvatarDescriptor.initials(from: name)
        guard let photo = item.photo else {
            return remote(item, id: id, initials: initials)
        }

        let url = MediaStore.url(for: photo)
        let image = AvatarImage(key: "me:\(photo.name)") {
            try? Data(contentsOf: url)
        }

        return AvatarDescriptor(
            id: id,
            initials: initials,
            image: image,
            video: item.video.map { video in
                AvatarVideo(key: "me:\(video.name)", url: MediaStore.url(for: video))
            }
        )
    }

    private func remote(_ item: MyProfilePhoto, id: String, initials: String) -> AvatarDescriptor {
        guard let files, let photoID = item.photoMediaID else {
            return AvatarDescriptor(id: id, initials: initials)
        }

        return RemoteAvatar(
            subject: "",
            username: "",
            photoMediaID: photoID,
            videoMediaID: item.videoMediaID ?? "",
            files: files
        ).descriptor(id: id, initials: initials)
    }

    private func removeLostFiles(_ next: MyProfile) {
        let kept = Set(next.photos.flatMap { item in
            [item.photo, item.video].compactMap(\.self)
        })
        for item in profile.photos {
            for file in [item.photo, item.video].compactMap(\.self) where !kept.contains(file) {
                media.remove(file)
            }
        }
    }
}
