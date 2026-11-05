enum AuthStep {
    case welcome
    case sessionEnded(canSwitch: Bool)
    case profile

    var fields: [AuthFieldKind] {
        switch self {
        case .profile:
            [.firstName, .lastName, .username]
        case .welcome, .sessionEnded:
            []
        }
    }

    var isCentered: Bool {
        fields.isEmpty
    }

    var showsWordmark: Bool {
        fields.isEmpty
    }

    func content(_ strings: AppStrings) -> AuthStepContent {
        switch self {
        case .welcome:
            AuthStepContent(
                hero: .wordmark,
                title: strings.authWelcomeTitle,
                message: strings.authWelcomeMessage,
                primary: strings.authContinue
            )
        case .sessionEnded(let canSwitch):
            AuthStepContent(
                hero: .wordmark,
                title: strings.authEndedTitle,
                message: strings.authEndedMessage,
                primary: strings.authContinue,
                secondary: canSwitch ? strings.accountOther : nil
            )
        case .profile:
            AuthStepContent(
                hero: .symbol("person.crop.circle.fill"),
                title: strings.authProfileTitle,
                message: strings.authProfileMessage,
                primary: strings.authProfileDone
            )
        }
    }
}

struct AuthStepContent {
    enum Hero {
        case wordmark
        case symbol(String)
    }

    let hero: Hero
    let title: String
    let message: String
    let primary: String
    var secondary: String?
}

enum AuthFieldKind {
    case firstName
    case lastName
    case username

    func placeholder(_ strings: AppStrings) -> String {
        switch self {
        case .firstName:
            strings.profileEditFirstName
        case .lastName:
            strings.profileEditLastName
        case .username:
            strings.authProfileUsername
        }
    }

    func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .firstName:
            return !trimmed.isEmpty
        case .lastName:
            return true
        case .username:
            return trimmed.isEmpty || MyProfile.isValidUsername(trimmed)
        }
    }
}
