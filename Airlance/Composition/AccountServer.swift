import Auth
import Foundation
import Observers
import os
import Protocol
import ServerConnection
import UIKit
import WireAuth

struct ServerProfile: Sendable {
    let firstName: String
    let lastName: String
    let username: String
    let bio: String
    var phone = ""
    var photos: [ProfilePhotoData] = []
    var updatedAtUnix: Int64 = 0

    init(_ data: ProfileData) {
        firstName = data.fields.firstName
        lastName = data.fields.lastName
        username = data.fields.username
        bio = data.fields.bio
        phone = data.fields.phone
        photos = data.photos
        updatedAtUnix = data.updatedAtUnix
    }

    init(_ fields: AuthProfileFields) {
        firstName = fields.firstName
        lastName = fields.lastName
        username = fields.username
        bio = ""
    }

    init(_ profile: MyProfile) {
        firstName = profile.firstName
        lastName = profile.lastName
        username = profile.username
        bio = profile.bio
        phone = profile.phone
    }

    func hasSameFields(as other: ServerProfile?) -> Bool {
        firstName == other?.firstName
            && lastName == other?.lastName
            && username == other?.username
            && bio == other?.bio
            && phone == other?.phone
    }
}

enum AccountServerError: Error {
    case refused(code: Int32, message: String)
    case unexpectedReply
}

@MainActor
final class AccountServer {
    private static let logger = Logger(subsystem: "Airlance", category: "Server")

    var onMissingProfile: (@MainActor () -> Void)?
    var onSessionEnded: (@MainActor () -> Void)?
    var onSaveFailed: (@MainActor (any Error) -> Void)?

    let media: ProfileMediaSync

    private let connection: ServerConnection
    private weak var store: MyProfileStore?
    private var observation: ObservationToken?
    private var synced: ServerProfile?
    private var sync: AccountSync?
    private var stories: AccountStories?
    private(set) var messaging: AccountMessaging?

    init(connection: ServerConnection) {
        self.connection = connection
        media = ProfileMediaSync(connection: connection)
        media.onFailed = { [weak self] error in
            self?.onSaveFailed?(error)
        }
        media.onProfile = { [weak self] data in
            self?.apply(ServerProfile(data))
        }
    }

    func fetchProfile() async throws -> ServerProfile? {
        do {
            return try Self.profile(from: try await connection.request(.profileGet))
        } catch AccountServerError.refused(let code, _) where code == 404 {
            return nil
        }
    }

    func saveProfile(_ profile: ServerProfile) async throws -> ServerProfile {
        let fields = ProfileFields(
            firstName: profile.firstName,
            lastName: profile.lastName,
            username: profile.username,
            bio: profile.bio,
            phone: profile.phone
        )

        return try Self.profile(from: try await connection.request(.profileSet(fields)))
    }

    func attach(_ store: MyProfileStore) {
        guard self.store !== store else {
            return
        }

        self.store = store
        media.attach(store)
        observation = store.observe { [weak self] profile in
            self?.localChanged(profile)
        }
    }

    func follow(_ account: AccountContext) {
        if sync == nil {
            sync = makeSync(account)
        }
        sync?.start()
        stories?.refresh()
        account.serverContacts.attach(connection)
        account.serverContacts.refresh()
        account.privacy.attach(connection)
        account.privacy.refresh()
        let connection = connection
        let files = account.profileFiles
        Task {
            await files.attach(connection)
        }
    }

    func suspend() async {
        sync?.stop()
        await connection.close()
    }

    func apply(_ remote: ServerProfile) {
        guard remote.updatedAtUnix >= synced?.updatedAtUnix ?? 0 else {
            return
        }

        synced = remote
        guard let store else {
            return
        }

        var next = store.profile
        next.firstName = remote.firstName
        next.lastName = remote.lastName
        next.username = remote.username
        next.bio = remote.bio
        next.phone = remote.phone
        ProfileMediaSync.merge(remote, into: &next)
        store.update(next)
        media.sync()
    }

    func pull() async {
        do {
            if let remote = try await fetchProfile() {
                apply(remote)
            } else {
                onMissingProfile?()
            }
        } catch AuthError.sessionEnded, ServerConnectionError.unauthorized {
            onSessionEnded?()
        } catch {
            Self.logger.error("Can't load the profile: \(String(describing: error))")
        }
    }

    func close() async {
        observation = nil
        await suspend()
    }

    private func makeSync(_ account: AccountContext) -> AccountSync {
        let history = account.historyStore
        let messaging = AccountMessaging(
            connection: connection,
            storage: account.chatStorage,
            me: account.record.subject ?? ""
        ) { [weak history] chatID in
            history?.isViewed(chatID) ?? false
        }
        self.messaging = messaging
        history.serverSender = { [weak messaging] message in
            messaging?.send(message)
        }
        let sync = AccountSync(
            connection: connection,
            storage: account.storage,
            chats: account.chatStorage,
            messaging: messaging,
            status: account.connectionStatus
        )
        let stories = AccountStories(connection: connection, files: account.profileFiles, store: account.storiesStore)
        self.stories = stories
        sync.onStoriesChanged = { [weak stories, weak account] in
            stories?.refresh()
            account?.privacy.refresh()
        }
        sync.onContactsChanged = { [weak account] in
            account?.serverContacts.refresh()
        }
        sync.onProfile = { [weak self] data in
            self?.apply(ServerProfile(data))
        }
        sync.onJournalLost = { [weak self] in
            Task {
                await self?.pull()
            }
        }
        sync.onSessionEnded = { [weak self] in
            self?.onSessionEnded?()
        }

        return sync
    }

    private func localChanged(_ profile: MyProfile) {
        media.sync()
        let local = ServerProfile(profile)
        guard !local.hasSameFields(as: synced) else {
            return
        }

        Task {
            do {
                apply(try await saveProfile(local))
            } catch {
                onSaveFailed?(error)
                await pull()
            }
        }
    }

    private static func profile(from reply: ProtocolMessage) throws -> ServerProfile {
        switch reply {
        case .profileData(let data):
            ServerProfile(data)
        case .error(let error):
            throw AccountServerError.refused(code: error.code, message: error.message)
        default:
            throw AccountServerError.unexpectedReply
        }
    }
}

@MainActor
final class AccountServers {
    private static let socketURL = URL(string: "wss://api.airlance.org/v1/ws")
    private static let pins = [
        WireAuthPin(id: 1, publicKeyBase64: "Y5c3mSTAnF4RcXnRXYopZZBNmzPzcWBcd/cMcdKdxyE="),
    ].compactMap(\.self)

    private let auth: AuthTokenStore
    private var servers: [AccountID: AccountServer] = [:]
    private var backgroundObserver: (any NSObjectProtocol)?

    init(auth: AuthTokenStore) {
        self.auth = auth
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.suspendAll()
            }
        }
    }

    private func suspendAll() {
        for server in servers.values {
            Task {
                await server.suspend()
            }
        }
    }

    func server(for id: AccountID) -> AccountServer? {
        if let server = servers[id] {
            return server
        }

        guard let url = Self.socketURL else {
            return nil
        }

        let auth = auth
        let account = id.rawValue
        let server = AccountServer(connection: ServerConnection(url: url, pins: Self.pins) {
            try await auth.validAccessToken(account: account)
        })
        servers[id] = server

        return server
    }

    func remove(_ id: AccountID) {
        guard let server = servers.removeValue(forKey: id) else {
            return
        }

        Task {
            await server.close()
        }
    }
}
