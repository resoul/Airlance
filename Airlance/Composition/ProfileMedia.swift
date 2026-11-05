import AvatarUI
import ChatStorage
import Foundation
import MediaStore
import Protocol
import ServerConnection

enum ProfileMediaError: Error {
    case refused
    case transferFailed
}

actor ProfileMediaFiles {
    private var connection: ServerConnection?
    private var waiters: [CheckedContinuation<ServerConnection, Never>] = []
    private var downloads: [String: Task<URL?, Never>] = [:]

    init(connection: ServerConnection? = nil) {
        self.connection = connection
    }

    func attach(_ connection: ServerConnection) {
        self.connection = connection
        for waiter in waiters {
            waiter.resume(returning: connection)
        }
        waiters = []
    }

    nonisolated static func cached(_ mediaID: String, extension ext: String) -> URL? {
        guard let name = safeName(mediaID, extension: ext) else {
            return nil
        }

        let url = directory.appendingPathComponent(name)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func upload(_ file: URL) async throws -> String {
        let size = MediaStore.size(of: file)
        let reply = try await attached().request(.media(.uploadRequest(size: size)))
        guard case .media(.uploadTicket(let mediaID, let address, _)) = reply, let url = URL(string: address) else {
            throw ProfileMediaError.refused
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: file)
        guard Self.isSuccess(response) else {
            throw ProfileMediaError.transferFailed
        }

        return mediaID
    }

    func file(_ mediaID: String, extension ext: String) async -> URL? {
        if let cached = Self.cached(mediaID, extension: ext) {
            return cached
        }

        if let running = downloads[mediaID] {
            return await running.value
        }

        let task = Task {
            await self.download(mediaID, extension: ext)
        }
        downloads[mediaID] = task
        let result = await task.value
        downloads[mediaID] = nil

        return result
    }

    private func download(_ mediaID: String, extension ext: String) async -> URL? {
        guard let name = Self.safeName(mediaID, extension: ext) else {
            return nil
        }

        let connection = await attached()
        guard case .media(.downloadTicket(let address, _))? = try? await connection.request(
            .media(.downloadRequest(mediaID: mediaID))
        ),
              let url = URL(string: address),
              let (temporary, response) = try? await URLSession.shared.download(from: url),
              Self.isSuccess(response) else {
            return nil
        }

        let manager = FileManager.default
        let target = Self.directory.appendingPathComponent(name)
        try? manager.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try? manager.removeItem(at: target)
        guard (try? manager.moveItem(at: temporary, to: target)) != nil else {
            return nil
        }

        return target
    }

    nonisolated private static func isSuccess(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else {
            return false
        }

        return (200..<300).contains(http.statusCode)
    }

    private func attached() async -> ServerConnection {
        if let connection {
            return connection
        }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    nonisolated private static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProfileMedia", isDirectory: true)
    }

    nonisolated private static func safeName(_ mediaID: String, extension ext: String) -> String? {
        let isSafe = !mediaID.isEmpty && mediaID.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber)
        }

        return isSafe ? "\(mediaID).\(ext)" : nil
    }
}

struct RemoteAvatar: Sendable {
    let subject: String
    let username: String
    let photoMediaID: String
    let videoMediaID: String
    let files: ProfileMediaFiles

    func descriptor(id: String, initials: String) -> AvatarDescriptor {
        AvatarDescriptor(id: id, initials: initials, image: image(), video: video())
    }

    private func image() -> AvatarImage? {
        guard !photoMediaID.isEmpty else {
            return nil
        }

        let mediaID = photoMediaID
        let files = files

        return AvatarImage(key: "remote:\(mediaID)") {
            guard let url = await files.file(mediaID, extension: "jpg") else {
                return nil
            }

            return try? Data(contentsOf: url)
        }
    }

    private func video() -> AvatarVideo? {
        guard !videoMediaID.isEmpty else {
            return nil
        }

        guard let url = ProfileMediaFiles.cached(videoMediaID, extension: "mp4") else {
            let mediaID = videoMediaID
            let files = files
            Task {
                _ = await files.file(mediaID, extension: "mp4")
            }

            return nil
        }

        return AvatarVideo(key: "remote:\(videoMediaID)", url: url)
    }
}

@MainActor
final class ProfileMediaSync {
    var onFailed: (@MainActor (any Error) -> Void)?
    var onProfile: (@MainActor (ProfileData) -> Void)?

    private let connection: ServerConnection
    private let files: ProfileMediaFiles
    private weak var store: MyProfileStore?
    private var isRunning = false

    init(connection: ServerConnection) {
        self.connection = connection
        files = ProfileMediaFiles(connection: connection)
    }

    func attach(_ store: MyProfileStore) {
        self.store = store
    }

    static func merge(_ remote: ServerProfile, into profile: inout MyProfile) {
        let removed = Set(profile.photoRemovals ?? [])
        let pending = profile.photos.filter { item in
            item.photoMediaID == nil
        }
        let kept = remote.photos.filter { photo in
            !removed.contains(photo.photoMediaID)
        }
        var merged = kept.map { photo in
            var item = profile.photos.first { candidate in
                candidate.photoMediaID == photo.photoMediaID
            } ?? MyProfilePhoto()
            item.photoMediaID = photo.photoMediaID
            item.videoMediaID = photo.videoMediaID.isEmpty ? nil : photo.videoMediaID
            item.addedAtUnix = photo.addedAtUnix

            return item
        }
        if let main = profile.mainPhotoID, let position = merged.firstIndex(where: { item in
            item.photoMediaID == main
        }) {
            merged.insert(merged.remove(at: position), at: 0)
        }
        profile.photos = pending + merged
    }

    func sync() {
        guard !isRunning, store != nil else {
            return
        }

        isRunning = true
        Task {
            do {
                while try await step() {}
            } catch {
                onFailed?(error)
            }
            isRunning = false
        }
    }

    private func step() async throws -> Bool {
        guard let store else {
            return false
        }

        let profile = store.profile
        if let removal = profile.photoRemovals?.first {
            try await remove(removal)

            return true
        }

        if let pending = profile.photos.last(where: { item in
            item.photoMediaID == nil
        }) {
            try await upload(pending)

            return true
        }

        if let main = profile.mainPhotoID {
            try await raise(main)

            return true
        }

        return false
    }

    private func remove(_ id: String) async throws {
        let data = try await request(.profilePhotoRemove(photoMediaID: id))
        guard let store else {
            return
        }

        var next = store.profile
        next.photoRemovals?.removeAll { candidate in
            candidate == id
        }
        store.update(next)
        onProfile?(data)
    }

    private func upload(_ item: MyProfilePhoto) async throws {
        guard let photo = item.photo else {
            try dropBroken(item)

            return
        }

        let photoID = try await files.upload(MediaStore.url(for: photo))
        var videoID = ""
        if let video = item.video {
            videoID = try await files.upload(MediaStore.url(for: video))
        }
        guard store?.profile.photos.contains(item) == true else {
            return
        }

        let data = try await request(.profilePhotoAdd(photoMediaID: photoID, videoMediaID: videoID))
        guard let store else {
            return
        }

        var next = store.profile
        if let position = next.photos.firstIndex(of: item) {
            next.photos[position].photoMediaID = photoID
            next.photos[position].videoMediaID = videoID.isEmpty ? nil : videoID
        }
        store.update(next)
        onProfile?(data)
    }

    private func raise(_ id: String) async throws {
        guard let store else {
            return
        }

        let video = store.profile.photos.first { item in
            item.photoMediaID == id
        }?.videoMediaID
        let data = try await request(.profilePhotoAdd(photoMediaID: id, videoMediaID: video ?? ""))
        var next = store.profile
        if next.mainPhotoID == id {
            next.mainPhotoID = nil
        }
        store.update(next)
        onProfile?(data)
    }

    private func dropBroken(_ item: MyProfilePhoto) throws {
        guard let store else {
            return
        }

        var next = store.profile
        next.photos.removeAll { candidate in
            candidate == item
        }
        store.update(next)
    }

    private func request(_ message: ProtocolMessage) async throws -> ProfileData {
        switch try await connection.request(message) {
        case .profileData(let data):
            return data
        case .error(let error):
            throw AccountServerError.refused(code: error.code, message: error.message)
        default:
            throw AccountServerError.unexpectedReply
        }
    }
}

extension AccountContext {
    func registerOwnStories() {
        guard let subject = record.subject else {
            return
        }

        storiesStore.useServer(subject: subject, name: myProfile.profile.fullName)
        ownAvatar(myProfile.profile, subject: subject)
        ownProfileObservation = myProfile.observe { [weak self] profile in
            self?.ownAvatar(profile, subject: subject)
            self?.storiesStore.setOwnName(profile.fullName)
        }
    }

    private func ownAvatar(_ profile: MyProfile, subject: String) {
        let first = profile.photos.first
        PeerAvatars.register(
            RemoteAvatar(
                subject: subject,
                username: profile.username,
                photoMediaID: first?.photoMediaID ?? "",
                videoMediaID: first?.videoMediaID ?? "",
                files: profileFiles
            ),
            for: subject
        )
    }

    func registerPeerAvatars(_ chats: [StoredChat]) {
        let files = profileFiles
        for chat in chats {
            let avatar = RemoteAvatar(
                subject: chat.peer.subject,
                username: chat.peer.username,
                photoMediaID: chat.peer.photoMediaID,
                videoMediaID: chat.peer.videoMediaID,
                files: files
            )
            PeerAvatars.register(avatar, for: chat.id)
            PeerAvatars.register(avatar, for: chat.peer.subject)
        }
    }
}
