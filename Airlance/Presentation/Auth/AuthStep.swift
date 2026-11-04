enum AuthStep {
    case welcome
    case sessionEnded(canSwitch: Bool)
    case entry
    case code(email: String)
    case createPasskey
    case usePasskey
    case recovery
    case replacePasskey
    case recoveryCodes
    case profile

    var fields: [AuthFieldKind] {
        switch self {
        case .entry:
            [.email]
        case .code:
            [.code]
        case .recovery:
            [.recovery]
        case .profile:
            [.name, .username]
        case .welcome, .sessionEnded, .createPasskey, .usePasskey, .replacePasskey, .recoveryCodes:
            []
        }
    }

    var isCentered: Bool {
        fields.isEmpty
    }

    var showsWordmark: Bool {
        switch self {
        case .welcome, .sessionEnded:
            true
        default:
            false
        }
    }

    func content(_ strings: AppStrings) -> AuthStepContent {
        switch self {
        case .welcome, .sessionEnded, .profile:
            appContent(strings)
        case .entry, .code, .recovery:
            formContent(strings)
        case .createPasskey, .usePasskey, .replacePasskey, .recoveryCodes:
            passkeyContent(strings)
        }
    }

    private func appContent(_ strings: AppStrings) -> AuthStepContent {
        switch self {
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
        default:
            AuthStepContent(
                hero: .wordmark,
                title: strings.authWelcomeTitle,
                message: strings.authWelcomeMessage,
                primary: strings.authContinue
            )
        }
    }

    private func formContent(_ strings: AppStrings) -> AuthStepContent {
        switch self {
        case .code(let email):
            AuthStepContent(
                hero: .symbol("envelope.fill"),
                title: strings.authCodeTitle,
                message: strings.authCodeMessage(email),
                primary: strings.authContinue
            )
        case .recovery:
            AuthStepContent(
                hero: .symbol("lifepreserver.fill"),
                title: strings.authRecoveryTitle,
                message: strings.authRecoveryMessage,
                primary: strings.authContinue
            )
        default:
            AuthStepContent(
                hero: .symbol("at"),
                title: strings.authEntryTitle,
                message: strings.authEntryMessage,
                primary: strings.authEntrySend,
                secondary: strings.authEntryPasskey
            )
        }
    }

    private func passkeyContent(_ strings: AppStrings) -> AuthStepContent {
        switch self {
        case .usePasskey:
            AuthStepContent(
                hero: .symbol("person.badge.key.fill"),
                title: strings.authUseTitle,
                message: strings.authUseMessage,
                primary: strings.authUseAction,
                secondary: strings.authUseLost
            )
        case .replacePasskey:
            AuthStepContent(
                hero: .symbol("key.fill"),
                title: strings.authReplaceTitle,
                message: strings.authReplaceMessage,
                primary: strings.authCreateAction
            )
        case .recoveryCodes:
            AuthStepContent(
                hero: .symbol("checkmark.shield.fill"),
                title: strings.authCodesTitle,
                message: strings.authCodesMessage,
                primary: strings.authCodesSaved,
                secondary: strings.authCodesCopy
            )
        default:
            AuthStepContent(
                hero: .symbol("key.fill"),
                title: strings.authCreateTitle,
                message: strings.authCreateMessage,
                primary: strings.authCreateAction
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
    case email
    case code
    case recovery
    case name
    case username

    func placeholder(_ strings: AppStrings) -> String {
        switch self {
        case .email:
            strings.authEntryEmail
        case .code:
            "0000 0000"
        case .recovery:
            strings.authRecoveryPlaceholder
        case .name:
            strings.authProfileName
        case .username:
            strings.authProfileUsername
        }
    }

    func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .email:
            let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)

            return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
        case .code:
            return trimmed.count == Self.codeLength
        case .recovery, .name:
            return !trimmed.isEmpty
        case .username:
            return trimmed.isEmpty || MyProfile.isValidUsername(trimmed)
        }
    }

    func sanitized(_ text: String) -> String {
        guard self == .code else {
            return text
        }

        return String(text.filter(\.isNumber).prefix(Self.codeLength))
    }

    private static let codeLength = 8
}
