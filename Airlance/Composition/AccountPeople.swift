import DeviceContacts
import Foundation
import Observers
import os
import Protocol
import ServerConnection

@MainActor
final class ServerContactsStore {
    private static let logger = Logger(subsystem: "Airlance", category: "Contacts")

    let isServerBacked: Bool

    private(set) var contacts: [ServerContact] = []
    private(set) var matchedPhones: Set<String> = []
    private let files: ProfileMediaFiles
    private let observers = ObserverList<[ServerContact]>()
    private var connection: ServerConnection?
    private var lastSynced: Set<String>?

    init(isServerBacked: Bool, files: ProfileMediaFiles) {
        self.isServerBacked = isServerBacked
        self.files = files
    }

    func attach(_ connection: ServerConnection) {
        self.connection = connection
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([ServerContact]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(contacts)

        return token
    }

    func contact(for subject: String) -> ServerContact? {
        contacts.first { contact in
            contact.person.subject == subject
        }
    }

    func refresh() {
        Task {
            try? await send(.get)
        }
    }

    func add(subject: String, firstName: String, lastName: String) async throws {
        try await send(.add(subject: subject, firstName: firstName, lastName: lastName))
    }

    func addPhone(_ phone: String, firstName: String, lastName: String) async throws {
        let digits = PhoneDigits.international(phone, region: PhoneDigits.currentRegion)
        try await send(.addPhone(phone: digits, firstName: firstName, lastName: lastName))
    }

    func remove(subject: String) async throws {
        try await send(.remove(subject: subject))
    }

    func syncDevice(_ device: [DeviceContact]) {
        guard isServerBacked, connection != nil else {
            return
        }

        let region = PhoneDigits.currentRegion
        let phones = Set(device.flatMap(\.phoneNumbers).map { number in
            PhoneDigits.international(number, region: region)
        })
        guard phones != lastSynced else {
            return
        }

        lastSynced = phones
        Task {
            do {
                let list = try await request(.sync(Array(phones).sorted()))
                matchedPhones = Set(list.map(\.phone))
                apply(list)
            } catch {
                lastSynced = nil
                Self.logger.debug("Can't match the contacts: \(String(describing: error))")
            }
        }
    }

    private func send(_ message: ContactWireMessage) async throws {
        apply(try await request(message))
    }

    private func request(_ message: ContactWireMessage) async throws -> [ServerContact] {
        guard let connection else {
            throw AccountMessagingError.refused
        }

        switch try await connection.request(.contact(message)) {
        case .contact(.list(let list)):
            return list
        case .error(let error):
            throw AccountServerError.refused(code: error.code, message: error.message)
        default:
            throw AccountServerError.unexpectedReply
        }
    }

    private func apply(_ list: [ServerContact]) {
        contacts = list
        for contact in list {
            let avatar = RemoteAvatar(
                subject: contact.person.subject,
                username: contact.person.username,
                photoMediaID: contact.person.photoMediaID,
                videoMediaID: contact.person.videoMediaID,
                files: files
            )
            PeerAvatars.register(avatar, for: contact.person.subject)
        }
        observers.notify(list)
    }
}

@MainActor
final class PrivacyStore {
    private(set) var settings = PrivacySettings()
    private(set) var blocked: [SearchPerson] = []
    private let observers = ObserverList<PrivacySettings>()
    private var connection: ServerConnection?

    func attach(_ connection: ServerConnection) {
        self.connection = connection
    }

    func observe(_ onChange: @escaping @MainActor @Sendable (PrivacySettings) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(settings)

        return token
    }

    func isBlocked(_ subject: String) -> Bool {
        blocked.contains { person in
            person.subject == subject
        }
    }

    func refresh() {
        Task {
            if case .privacy(.settings(let next))? = try? await reply(.get) {
                settings = next
            }
            if case .privacy(.blocks(let people))? = try? await reply(.blocksGet) {
                blocked = people
            }
            observers.notify(settings)
        }
    }

    func update(_ next: PrivacySettings) async throws {
        let old = settings
        settings = next
        observers.notify(next)
        guard connection != nil else {
            return
        }

        do {
            if case .privacy(.settings(let saved)) = try await reply(.set(next)) {
                settings = saved
            }
        } catch {
            settings = old
            observers.notify(old)
            throw error
        }
        observers.notify(settings)
    }

    func setBlocked(_ subject: String, isBlocked: Bool) async throws {
        if case .privacy(.blocks(let people)) = try await reply(.block(subject: subject, isBlocked: isBlocked)) {
            blocked = people
            observers.notify(settings)
        }
    }

    private func reply(_ message: PrivacyWireMessage) async throws -> ProtocolMessage {
        guard let connection else {
            throw AccountMessagingError.refused
        }

        let answer = try await connection.request(.privacy(message))
        if case .error(let error) = answer {
            throw AccountServerError.refused(code: error.code, message: error.message)
        }

        return answer
    }
}
