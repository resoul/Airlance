import Contacts
import Foundation

enum DeviceContactsReader {
    static var isAuthorized: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18.0, *), status == .limited {
            return true
        }

        return status == .authorized
    }

    static func read(sort: DeviceContactsSort) throws -> [DeviceContact] {
        guard isAuthorized else {
            return []
        }

        let keys: [any CNKeyDescriptor] = [
            CNContactIdentifierKey as NSString,
            CNContactGivenNameKey as NSString,
            CNContactFamilyNameKey as NSString,
            CNContactOrganizationNameKey as NSString,
            CNContactPhoneNumbersKey as NSString,
            CNContactImageDataAvailableKey as NSString,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = sort == .givenName ? .givenName : .familyName

        var contacts: [DeviceContact] = []
        try CNContactStore().enumerateContacts(with: request) { contact, _ in
            if let converted = convert(contact) {
                contacts.append(converted)
            }
        }

        return contacts
    }

    private static func convert(_ contact: CNContact) -> DeviceContact? {
        let phones = contact.phoneNumbers.map { number in
            number.value.stringValue
        }
        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        let name = [formatted, contact.organizationName, phones.first ?? ""].first { candidate in
            !candidate.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard let name else {
            return nil
        }

        return DeviceContact(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            displayName: name,
            phoneNumbers: phones,
            hasImage: contact.imageDataAvailable
        )
    }
}
