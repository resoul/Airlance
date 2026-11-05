import Foundation

public struct DeviceContact: Sendable, Equatable, Identifiable {
    public let id: String
    public let givenName: String
    public let familyName: String
    public let displayName: String
    public let phoneNumbers: [String]
    public let hasImage: Bool

    public init(
        id: String,
        givenName: String,
        familyName: String,
        displayName: String,
        phoneNumbers: [String],
        hasImage: Bool
    ) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.displayName = displayName
        self.phoneNumbers = phoneNumbers
        self.hasImage = hasImage
    }

    public func matches(_ query: String) -> Bool {
        let digits = query.filter(\.isNumber)

        return displayName.localizedCaseInsensitiveContains(query)
            || (!digits.isEmpty && phoneNumbers.contains { number in
                number.filter(\.isNumber).contains(digits)
            })
    }
}

public enum DeviceContactsSort: String, Codable, Sendable, CaseIterable {
    case givenName
    case familyName
}
