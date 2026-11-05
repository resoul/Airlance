internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeReader {
    func contact(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .contactsget:
            let _: Airlance_Wire_ContactsGet = try checkedRoot(body)

            return .contact(.get)
        case .contactsdata:
            let table: Airlance_Wire_ContactsData = try checkedRoot(body)

            return .contact(.list(table.contacts.map(Self.serverContact)))
        case .contactadd:
            let table: Airlance_Wire_ContactAdd = try checkedRoot(body)

            return .contact(.add(
                subject: table.subject ?? "",
                firstName: table.customFirstName ?? "",
                lastName: table.customLastName ?? ""
            ))
        case .contactaddphone:
            let table: Airlance_Wire_ContactAddPhone = try checkedRoot(body)

            return .contact(.addPhone(
                phone: table.phone ?? "",
                firstName: table.customFirstName ?? "",
                lastName: table.customLastName ?? ""
            ))
        case .contactremove:
            let table: Airlance_Wire_ContactRemove = try checkedRoot(body)

            return .contact(.remove(subject: table.subject ?? ""))
        case .contactssync:
            let table: Airlance_Wire_ContactsSync = try checkedRoot(body)

            return .contact(.sync(table.phones.compactMap(\.self)))
        default:
            let _: Airlance_Wire_ContactsChanged = try checkedRoot(body)

            return .contact(.changed)
        }
    }

    func privacy(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .privacyget:
            let _: Airlance_Wire_PrivacyGet = try checkedRoot(body)

            return .privacy(.get)
        case .privacyset:
            let table: Airlance_Wire_PrivacySet = try checkedRoot(body)

            return .privacy(.set(Self.settings(table.phone, table.photos, table.bio, table.messages, table.search)))
        case .privacydata:
            let table: Airlance_Wire_PrivacyData = try checkedRoot(body)

            let settings = Self.settings(table.phone, table.photos, table.bio, table.messages, table.search)

            return .privacy(.settings(settings))
        case .blocksget:
            let _: Airlance_Wire_BlocksGet = try checkedRoot(body)

            return .privacy(.blocksGet)
        case .blocksdata:
            let table: Airlance_Wire_BlocksData = try checkedRoot(body)

            return .privacy(.blocks(table.people.map { row in
                SearchPerson(
                    subject: row.subject ?? "",
                    firstName: row.firstName ?? "",
                    lastName: row.lastName ?? "",
                    username: row.username ?? ""
                )
            }))
        default:
            let table: Airlance_Wire_BlockSet = try checkedRoot(body)

            return .privacy(.block(subject: table.subject ?? "", isBlocked: table.blocked))
        }
    }

    private static func settings(
        _ phone: Int32,
        _ photos: Int32,
        _ bio: Int32,
        _ messages: Int32,
        _ search: Int32
    ) -> PrivacySettings {
        var settings = PrivacySettings()
        settings.phone = PrivacyLevel(rawValue: phone) ?? .nobody
        settings.photos = PrivacyLevel(rawValue: photos) ?? .nobody
        settings.bio = PrivacyLevel(rawValue: bio) ?? .nobody
        settings.messages = PrivacyLevel(rawValue: messages) ?? .contacts
        settings.search = PrivacyLevel(rawValue: search) ?? .nobody

        return settings
    }

    private static func serverContact(_ row: Airlance_Wire_ContactData) -> ServerContact {
        ServerContact(
            person: SearchPerson(
                subject: row.subject ?? "",
                firstName: row.firstName ?? "",
                lastName: row.lastName ?? "",
                username: row.username ?? "",
                photoMediaID: row.photoMediaId ?? "",
                videoMediaID: row.videoMediaId ?? ""
            ),
            customFirstName: row.customFirstName ?? "",
            customLastName: row.customLastName ?? "",
            phone: row.phone ?? "",
            isFromDevice: row.fromDevice
        )
    }
}
