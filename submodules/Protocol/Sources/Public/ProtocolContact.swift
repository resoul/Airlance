public enum ContactWireMessage: Sendable, Equatable {
    case get
    case list([ServerContact])
    case add(subject: String, firstName: String, lastName: String)
    case addPhone(phone: String, firstName: String, lastName: String)
    case remove(subject: String)
    case sync([String])
    case changed
}

public struct ServerContact: Sendable, Equatable {
    public let person: SearchPerson
    public let customFirstName: String
    public let customLastName: String
    public let phone: String
    public let isFromDevice: Bool

    public var displayName: String {
        let custom = [customFirstName, customLastName].filter { part in
            !part.isEmpty
        }
        let own = [person.firstName, person.lastName].filter { part in
            !part.isEmpty
        }

        return (custom.isEmpty ? own : custom).joined(separator: " ")
    }

    public init(
        person: SearchPerson,
        customFirstName: String,
        customLastName: String,
        phone: String,
        isFromDevice: Bool
    ) {
        self.person = person
        self.customFirstName = customFirstName
        self.customLastName = customLastName
        self.phone = phone
        self.isFromDevice = isFromDevice
    }
}

public enum PrivacyLevel: Int32, Sendable, Equatable, CaseIterable {
    case everyone = 0
    case contacts = 1
    case nobody = 2
}

public struct PrivacySettings: Sendable, Equatable {
    public var phone = PrivacyLevel.nobody
    public var photos = PrivacyLevel.everyone
    public var bio = PrivacyLevel.everyone
    public var messages = PrivacyLevel.everyone
    public var search = PrivacyLevel.everyone

    public init() {}
}

public enum PrivacyWireMessage: Sendable, Equatable {
    case get
    case set(PrivacySettings)
    case settings(PrivacySettings)
    case blocksGet
    case blocks([SearchPerson])
    case block(subject: String, isBlocked: Bool)
}
