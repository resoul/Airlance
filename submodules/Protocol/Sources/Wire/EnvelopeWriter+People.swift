internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeWriter {
    static func writeContact(
        _ contact: ContactWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch contact {
        case .get:
            let start = Airlance_Wire_ContactsGet.startContactsGet(&builder)

            return (.contactsget, Airlance_Wire_ContactsGet.endContactsGet(&builder, start: start))
        case .list(let contacts):
            let rows = contacts.map { next in
                writeServerContact(next, into: &builder)
            }
            let vector = builder.createVector(ofOffsets: rows)
            let root = Airlance_Wire_ContactsData.createContactsData(&builder, contactsVectorOffset: vector)

            return (.contactsdata, root)
        case .add(let subject, let firstName, let lastName):
            return (.contactadd, writeAdd(subject, firstName, lastName, into: &builder))
        case .addPhone(let phone, let firstName, let lastName):
            return (.contactaddphone, writeAddPhone(phone, firstName, lastName, into: &builder))
        case .remove(let subject):
            let text = builder.create(string: subject)

            return (.contactremove, Airlance_Wire_ContactRemove.createContactRemove(&builder, subjectOffset: text))
        case .sync(let phones):
            let vector = builder.createVector(ofStrings: phones)

            return (.contactssync, Airlance_Wire_ContactsSync.createContactsSync(&builder, phonesVectorOffset: vector))
        case .changed:
            let start = Airlance_Wire_ContactsChanged.startContactsChanged(&builder)

            return (.contactschanged, Airlance_Wire_ContactsChanged.endContactsChanged(&builder, start: start))
        }
    }

    static func writePrivacy(
        _ privacy: PrivacyWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch privacy {
        case .get:
            let start = Airlance_Wire_PrivacyGet.startPrivacyGet(&builder)

            return (.privacyget, Airlance_Wire_PrivacyGet.endPrivacyGet(&builder, start: start))
        case .set(let settings):
            let root = Airlance_Wire_PrivacySet.createPrivacySet(
                &builder,
                phone: settings.phone.rawValue,
                photos: settings.photos.rawValue,
                bio: settings.bio.rawValue,
                messages: settings.messages.rawValue,
                search: settings.search.rawValue
            )

            return (.privacyset, root)
        case .settings(let settings):
            let root = Airlance_Wire_PrivacyData.createPrivacyData(
                &builder,
                phone: settings.phone.rawValue,
                photos: settings.photos.rawValue,
                bio: settings.bio.rawValue,
                messages: settings.messages.rawValue,
                search: settings.search.rawValue
            )

            return (.privacydata, root)
        case .blocksGet:
            let start = Airlance_Wire_BlocksGet.startBlocksGet(&builder)

            return (.blocksget, Airlance_Wire_BlocksGet.endBlocksGet(&builder, start: start))
        case .blocks(let people):
            let rows = people.map { person in
                writeBlockedPerson(person, into: &builder)
            }
            let vector = builder.createVector(ofOffsets: rows)

            return (.blocksdata, Airlance_Wire_BlocksData.createBlocksData(&builder, peopleVectorOffset: vector))
        case .block(let subject, let isBlocked):
            let text = builder.create(string: subject)

            return (.blockset, Airlance_Wire_BlockSet.createBlockSet(&builder, subjectOffset: text, blocked: isBlocked))
        }
    }

    private static func writeAdd(
        _ subject: String,
        _ firstName: String,
        _ lastName: String,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let text = builder.create(string: subject)
        let first = builder.create(string: firstName)
        let last = builder.create(string: lastName)

        return Airlance_Wire_ContactAdd.createContactAdd(
            &builder,
            subjectOffset: text,
            customFirstNameOffset: first,
            customLastNameOffset: last
        )
    }

    private static func writeAddPhone(
        _ phone: String,
        _ firstName: String,
        _ lastName: String,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let text = builder.create(string: phone)
        let first = builder.create(string: firstName)
        let last = builder.create(string: lastName)

        return Airlance_Wire_ContactAddPhone.createContactAddPhone(
            &builder,
            phoneOffset: text,
            customFirstNameOffset: first,
            customLastNameOffset: last
        )
    }

    private static func writeBlockedPerson(_ person: SearchPerson, into builder: inout FlatBufferBuilder) -> Offset {
        let subject = builder.create(string: person.subject)
        let first = builder.create(string: person.firstName)
        let last = builder.create(string: person.lastName)
        let username = builder.create(string: person.username)

        return Airlance_Wire_SearchPerson.createSearchPerson(
            &builder,
            subjectOffset: subject,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username
        )
    }

    private static func writeServerContact(_ contact: ServerContact, into builder: inout FlatBufferBuilder) -> Offset {
        let subject = builder.create(string: contact.person.subject)
        let first = builder.create(string: contact.person.firstName)
        let last = builder.create(string: contact.person.lastName)
        let username = builder.create(string: contact.person.username)
        let photo = builder.create(string: contact.person.photoMediaID)
        let video = builder.create(string: contact.person.videoMediaID)
        let customFirst = builder.create(string: contact.customFirstName)
        let customLast = builder.create(string: contact.customLastName)
        let phone = builder.create(string: contact.phone)

        return Airlance_Wire_ContactData.createContactData(
            &builder,
            subjectOffset: subject,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            photoMediaIdOffset: photo,
            videoMediaIdOffset: video,
            customFirstNameOffset: customFirst,
            customLastNameOffset: customLast,
            phoneOffset: phone,
            fromDevice: contact.isFromDevice
        )
    }
}
