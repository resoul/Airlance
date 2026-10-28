import Contacts

public struct DeviceContactDraft: Sendable {
    public let givenName: String
    public let familyName: String
    public let phoneNumber: String

    public init(givenName: String, familyName: String, phoneNumber: String) {
        self.givenName = givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.familyName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        (!givenName.isEmpty || !familyName.isEmpty) && phoneNumber.filter(\.isNumber).count >= 5
    }
}

enum DeviceContactsWriter {
    static func add(_ draft: DeviceContactDraft) throws {
        let contact = CNMutableContact()
        contact.givenName = draft.givenName
        contact.familyName = draft.familyName
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: draft.phoneNumber)),
        ]

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try CNContactStore().execute(request)
    }
}
